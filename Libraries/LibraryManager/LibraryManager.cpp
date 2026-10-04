#include "Libraries/LibraryManager/LibraryManager.h"
#include "Libraries/DocumentManager/DocumentBase.h"

#include <QFile>
#include <QSaveFile>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

LibraryManager::LibraryManager(QObject* parent)
    : QObject(parent) {
    // Before:
    // QString appDataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/ShokaReader";

    // Cleaned:
    QString appDataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(appDataDir);

    m_thumbnailsDirectory = appDataDir + "/thumbnails";
    QDir().mkpath(m_thumbnailsDirectory);

    m_libraryFilePath = appDataDir + "/library.json";
    loadLibrary();
}

// --- Serialization Helpers ---

QJsonObject BookmarkRecord::toJson() const {
    QJsonObject obj;
    obj["page"] = page;
    obj["title"] = title;
    obj["createdAt"] = createdAt;
    return obj;
}

BookmarkRecord BookmarkRecord::fromJson(const QJsonObject& json) {
    BookmarkRecord b;
    b.page = json["page"].toInt(1);
    b.title = json["title"].toString();
    b.createdAt = json["createdAt"].toVariant().toLongLong();
    return b;
}

QVariantMap BookmarkRecord::toVariantMap() const {
    QVariantMap map;
    map["page"] = page;
    map["title"] = title;
    map["createdAt"] = createdAt;
    return map;
}

QJsonObject DocumentRecord::toJson() const {
    QJsonObject obj;
    obj["fingerprint"] = fingerprint;
    obj["filePath"] = filePath;
    obj["title"] = title;
    obj["fileSize"] = fileSize;
    obj["lastOpenedTimestamp"] = lastOpenedTimestamp;
    obj["currentPage"] = currentPage;
    obj["totalPages"] = totalPages;
    obj["zoom"] = zoom;
    obj["rotation"] = rotation;
    obj["isActivelyReading"] = isActivelyReading;
    obj["isFavorite"] = isFavorite;
    obj["thumbnailPath"] = thumbnailPath;

    QJsonArray bookmarkArray;
    for (const auto& bm : bookmarks) {
        bookmarkArray.append(bm.toJson());
    }
    obj["bookmarks"] = bookmarkArray;
    return obj;
}

DocumentRecord DocumentRecord::fromJson(const QJsonObject& json) {
    DocumentRecord d;
    d.fingerprint = json["fingerprint"].toString();
    d.filePath = json["filePath"].toString();
    d.title = json["title"].toString();
    d.fileSize = json["fileSize"].toVariant().toLongLong();
    d.lastOpenedTimestamp = json["lastOpenedTimestamp"].toVariant().toLongLong();
    d.currentPage = json["currentPage"].toInt(1);
    d.totalPages = json["totalPages"].toInt(0);
    d.zoom = json["zoom"].toDouble(1.0);
    d.rotation = json["rotation"].toDouble(0.0);
    d.isActivelyReading = json["isActivelyReading"].toBool(false);
    d.isFavorite = json["isFavorite"].toBool(false);
    d.thumbnailPath = json["thumbnailPath"].toString();

    const QJsonArray bookmarkArray = json["bookmarks"].toArray();
    for (const auto& val : bookmarkArray) {
        d.bookmarks.append(BookmarkRecord::fromJson(val.toObject()));
    }
    return d;
}

QVariantMap DocumentRecord::toVariantMap() const {
    QVariantMap map;
    map["fingerprint"] = fingerprint;
    map["filePath"] = filePath;
    map["title"] = title;
    map["fileSize"] = fileSize;
    map["lastOpenedTimestamp"] = lastOpenedTimestamp;
    map["currentPage"] = currentPage;
    map["totalPages"] = totalPages;
    map["zoom"] = zoom;
    map["rotation"] = rotation;
    map["isActivelyReading"] = isActivelyReading;
    map["isFavorite"] = isFavorite;
    map["thumbnailPath"] = thumbnailPath;

    QVariantList bmList;
    for (const auto& bm : bookmarks) {
        bmList.append(bm.toVariantMap());
    }
    map["bookmarks"] = bmList;
    return map;
}

QString LibraryManager::computeFingerprint(const QString& localPath) const {
    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }

    qint64 size = file.size();
    QByteArray header = file.read(64 * 1024); // First 64 KB
    file.close();

    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(header);
    hash.addData(QByteArrayView(reinterpret_cast<const char*>(&size), sizeof(size)));

    return QString::fromLatin1(hash.result().toHex());
}

QString LibraryManager::getThumbnailFilePath(const QString& fingerprint) const {
    return m_thumbnailsDirectory + "/" + fingerprint + ".png";
}

void LibraryManager::generateThumbnailIfMissing(DocumentBase* doc, const QString& fingerprint) {
    if (doc == nullptr || fingerprint.isEmpty()) return;

    QString thumbPath = getThumbnailFilePath(fingerprint);
    if (QFile::exists(thumbPath)) return;

    QImage firstPage = doc->getPageImageData(0);
    if (!firstPage.isNull()) {
        QImage scaled = firstPage.scaledToHeight(360, Qt::SmoothTransformation);
        scaled.save(thumbPath, "PNG");
    }
}

void LibraryManager::recordDocumentOpened(DocumentBase* doc) {
    if (doc == nullptr) return;

    QString localPath = doc->getFileUrl().toLocalFile();
    QString fingerprint = computeFingerprint(localPath);
    if (fingerprint.isEmpty()) return;

    generateThumbnailIfMissing(doc, fingerprint);

    qint64 now = QDateTime::currentSecsSinceEpoch();
    m_lastReadFingerprint = fingerprint;

    if (!m_records.contains(fingerprint)) {
        DocumentRecord record;
        record.fingerprint = fingerprint;
        record.filePath = localPath;
        record.title = doc->getTitle();
        record.fileSize = QFileInfo(localPath).size();
        record.lastOpenedTimestamp = now;
        record.currentPage = 1;
        record.totalPages = doc->getTotalPageNumber();
        record.thumbnailPath = getThumbnailFilePath(fingerprint);
        record.isActivelyReading = false;
        m_records.insert(fingerprint, record);
    } else {
        m_records[fingerprint].filePath = localPath; // Update path if file moved
        m_records[fingerprint].lastOpenedTimestamp = now;
        m_records[fingerprint].totalPages = doc->getTotalPageNumber();
        if (m_records[fingerprint].thumbnailPath.isEmpty()) {
            m_records[fingerprint].thumbnailPath = getThumbnailFilePath(fingerprint);
        }
    }

    saveLibrary();
    emit libraryChanged();
}

void LibraryManager::updateSessionState(DocumentBase* doc, int currentPage, qreal zoom, qreal rotation) {
    if (doc == nullptr) return;

    QString localPath = doc->getFileUrl().toLocalFile();
    QString fingerprint = computeFingerprint(localPath);
    if (fingerprint.isEmpty() || !m_records.contains(fingerprint)) return;

    DocumentRecord& rec = m_records[fingerprint];
    rec.currentPage = currentPage;
    rec.zoom = zoom;
    rec.rotation = rotation;
    rec.lastOpenedTimestamp = QDateTime::currentSecsSinceEpoch();
    m_lastReadFingerprint = fingerprint;

    // Actively Reading state machine
    if (currentPage >= 2 && currentPage < rec.totalPages) {
        rec.isActivelyReading = true;
    } else if (currentPage >= rec.totalPages && rec.totalPages > 0) {
        rec.isActivelyReading = false;
    }

    saveLibrary();
    emit libraryChanged();
}

QVariantMap LibraryManager::getLastReadDocument() const {
    if (!m_lastReadFingerprint.isEmpty() && m_records.contains(m_lastReadFingerprint)) {
        return m_records[m_lastReadFingerprint].toVariantMap();
    }

    // Fallback: Pick record with highest timestamp
    qint64 maxTs = -1;
    QString latestFp;
    for (auto it = m_records.cbegin(); it != m_records.cend(); ++it) {
        if (it.value().lastOpenedTimestamp > maxTs) {
            maxTs = it.value().lastOpenedTimestamp;
            latestFp = it.key();
        }
    }

    if (!latestFp.isEmpty()) {
        return m_records[latestFp].toVariantMap();
    }

    return QVariantMap();
}

QVariantList LibraryManager::getActivelyReadingList() const {
    QVariantList list;
    QList<DocumentRecord> activeDocs;

    for (const auto& rec : m_records) {
        if (rec.isActivelyReading) {
            activeDocs.append(rec);
        }
    }

    // Sort by recent activity descending
    std::sort(activeDocs.begin(), activeDocs.end(), [](const DocumentRecord& a, const DocumentRecord& b) {
        return a.lastOpenedTimestamp > b.lastOpenedTimestamp;
    });

    for (const auto& rec : activeDocs) {
        list.append(rec.toVariantMap());
    }

    return list;
}

QVariantList LibraryManager::getFavoritesList() const {
    QVariantList list;
    QList<DocumentRecord> favDocs;

    for (const auto& rec : m_records) {
        if (rec.isFavorite) {
            favDocs.append(rec);
        }
    }

    std::sort(favDocs.begin(), favDocs.end(), [](const DocumentRecord& a, const DocumentRecord& b) {
        return a.lastOpenedTimestamp > b.lastOpenedTimestamp;
    });

    for (const auto& rec : favDocs) {
        list.append(rec.toVariantMap());
    }

    return list;
}

QVariantList LibraryManager::getBookmarks(const QString& fingerprint) const {
    QVariantList list;
    if (m_records.contains(fingerprint)) {
        for (const auto& bm : m_records[fingerprint].bookmarks) {
            list.append(bm.toVariantMap());
        }
    }
    return list;
}

bool LibraryManager::checkFileExists(const QString& filePath) const {
    return QFileInfo::exists(filePath);
}

void LibraryManager::toggleFavorite(const QString& fingerprint) {
    if (m_records.contains(fingerprint)) {
        m_records[fingerprint].isFavorite = !m_records[fingerprint].isFavorite;
        saveLibrary();
        emit libraryChanged();
    }
}

void LibraryManager::markAsFinished(const QString& fingerprint) {
    if (m_records.contains(fingerprint)) {
        m_records[fingerprint].isActivelyReading = false;
        saveLibrary();
        emit libraryChanged();
    }
}

void LibraryManager::addBookmark(const QString& fingerprint, int page, const QString& title) {
    if (!m_records.contains(fingerprint)) return;

    DocumentRecord& rec = m_records[fingerprint];
    // Check if bookmark on this page already exists
    for (auto& bm : rec.bookmarks) {
        if (bm.page == page) {
            bm.title = title;
            saveLibrary();
            emit libraryChanged();
            return;
        }
    }

    BookmarkRecord newBm;
    newBm.page = page;
    newBm.title = title.isEmpty() ? QString("Page %1").arg(page) : title;
    newBm.createdAt = QDateTime::currentSecsSinceEpoch();

    rec.bookmarks.append(newBm);
    saveLibrary();
    emit libraryChanged();
}

void LibraryManager::removeBookmark(const QString& fingerprint, int page) {
    if (!m_records.contains(fingerprint)) return;

    DocumentRecord& rec = m_records[fingerprint];
    rec.bookmarks.removeIf([page](const BookmarkRecord& bm) {
        return bm.page == page;
    });

    saveLibrary();
    emit libraryChanged();
}

void LibraryManager::removeDocumentRecord(const QString& fingerprint) {
    if (m_records.contains(fingerprint)) {
        // Remove thumbnail
        QFile::remove(m_records[fingerprint].thumbnailPath);
        m_records.remove(fingerprint);

        if (m_lastReadFingerprint == fingerprint) {
            m_lastReadFingerprint.clear();
        }

        saveLibrary();
        emit libraryChanged();
    }
}

QString LibraryManager::getDocumentFingerprint(DocumentBase* doc) const {
    if (doc == nullptr) {
        return QString();
    }
    return computeFingerprint(doc->getFileUrl().toLocalFile());
}

void LibraryManager::loadLibrary() {
    QFile file(m_libraryFilePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;

    QJsonObject root = doc.object();
    m_lastReadFingerprint = root["lastReadFingerprint"].toString();

    QJsonObject docsObj = root["documents"].toObject();
    m_records.clear();
    for (auto it = docsObj.begin(); it != docsObj.end(); ++it) {
        DocumentRecord rec = DocumentRecord::fromJson(it.value().toObject());
        m_records.insert(rec.fingerprint, rec);
    }
}

void LibraryManager::saveLibrary() {
    QJsonObject root;
    root["lastReadFingerprint"] = m_lastReadFingerprint;

    QJsonObject docsObj;
    for (auto it = m_records.begin(); it != m_records.end(); ++it) {
        docsObj.insert(it.key(), it.value().toJson());
    }
    root["documents"] = docsObj;

    QJsonDocument doc(root);
    QSaveFile file(m_libraryFilePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Indented));
        file.commit();
    }
}