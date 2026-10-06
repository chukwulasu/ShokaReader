#include "Libraries/DocumentManager/EpubDocument.h"

#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QPainter>
#include <QAbstractTextDocumentLayout>
#include <QTextBlock>
#include <QTextLayout>
#include <QThread>
#include <QThreadPool>
#include <QMutexLocker>
#include <QStringMatcher>
#include <cmath>
#include <cstring>
#include <algorithm>
#include <zlib.h>

#pragma pack(push, 1)
struct ZipLocalHeader {
    uint32_t signature;
    uint16_t versionNeeded;
    uint16_t flags;
    uint16_t compressionMethod;
    uint16_t lastModTime;
    uint16_t lastModDate;
    uint32_t crc32;
    uint32_t compressedSize;
    uint32_t uncompressedSize;
    uint16_t fileNameLength;
    uint16_t extraFieldLength;
};
#pragma pack(pop)

class EpubResourceDocument : public QTextDocument {
public:
    EpubResourceDocument(const QMap<QString, QByteArray>& zipEntries, const QString& chapterDir, QObject* parent = nullptr)
        : QTextDocument(parent), m_zipEntries(zipEntries), m_chapterDir(chapterDir) {}

protected:
    QVariant loadResource(int type, const QUrl &name) override {
        if (type == QTextDocument::ImageResource) {
            QString urlStr = name.toString();
            if (urlStr.startsWith("file:///")) {
                urlStr.remove(0, 8);
            }

            if (m_zipEntries.contains(urlStr)) {
                return QImage::fromData(m_zipEntries.value(urlStr));
            }

            QString rel = m_chapterDir.isEmpty() ? urlStr : (m_chapterDir + "/" + urlStr);
            rel = QDir::cleanPath(rel);
            if (m_zipEntries.contains(rel)) {
                return QImage::fromData(m_zipEntries.value(rel));
            }

            QString fileName = QFileInfo(urlStr).fileName();
            for (auto it = m_zipEntries.cbegin(); it != m_zipEntries.cend(); ++it) {
                if (it.key().endsWith("/" + fileName, Qt::CaseInsensitive) || it.key().compare(fileName, Qt::CaseInsensitive) == 0) {
                    return QImage::fromData(it.value());
                }
            }
        }
        return QTextDocument::loadResource(type, name);
    }

private:
    const QMap<QString, QByteArray>& m_zipEntries;
    QString m_chapterDir;
};

EpubDocument::EpubDocument(QObject* parent)
    : DocumentBase(parent) {
    m_canCopy = true;
}

EpubDocument::~EpubDocument() {
    cancelSearch();
    cancelBackgroundIndexing();
}

bool EpubDocument::unlock(const QString& userPassword, const QString& ownerPassword) {
    Q_UNUSED(userPassword);
    Q_UNUSED(ownerPassword);
    return false;
}

DocumentState EpubDocument::getDocumentMetaData(const QUrl& filePath) {
    cancelSearch();
    cancelBackgroundIndexing();

    m_fileUrl = filePath;
    QString localPath = filePath.toLocalFile();

    m_zipEntries.clear();
    m_spine.clear();
    m_manifest.clear();
    m_spineStartPage.clear();
    m_pageMappings.clear();
    m_tableOfContents.clear();

    {
        QMutexLocker locker(&m_textCacheMutex);
        m_chapterPlainTextCache.clear();
    }
    {
        QMutexLocker locker(&m_renderMutex);
        m_chapterLayoutCache.clear();
    }
    m_totalPageNumber = 0;

    if (!readZipArchive(localPath)) {
        return DocumentState::LoadFailed;
    }

    if (!parseContainerXml()) {
        return DocumentState::LoadFailed;
    }

    if (m_spine.isEmpty() || m_totalPageNumber <= 0) {
        return DocumentState::LoadFailed;
    }

    // Launch background text indexing
    startBackgroundTextIndexing();

    return DocumentState::LoadSuccessful;
}

void EpubDocument::cancelBackgroundIndexing() {
    m_indexingSessionId.fetch_add(1);
}

// Pure XML string extractor (100% thread-safe, no QTextDocument/QFont engine)
QString EpubDocument::extractPlainTextFromXml(const QByteArray& xmlData) {
    QString plainText;
    plainText.reserve(xmlData.size() / 2);

    QXmlStreamReader xml(xmlData);
    while (!xml.atEnd()) {
        xml.readNext();
        if (xml.isCharacters()) {
            plainText.append(xml.text());
        } else if (xml.isStartElement()) {
            const QStringView name = xml.name();
            if (name == QLatin1String("p") || name == QLatin1String("div") ||
                name == QLatin1String("h1") || name == QLatin1String("h2") ||
                name == QLatin1String("h3") || name == QLatin1String("br")) {
                plainText.append(QLatin1Char('\n'));
            }
        }
    }
    return plainText;
}

void EpubDocument::startBackgroundTextIndexing() {
    const uint64_t currentSession = ++m_indexingSessionId;
    if (m_spine.isEmpty()) return;

    QThreadPool::globalInstance()->start([this, currentSession]() {
        for (int s = 0; s < m_spine.size(); ++s) {
            if (m_indexingSessionId.load() != currentSession) return;

            {
                QMutexLocker locker(&m_textCacheMutex);
                if (s < m_chapterPlainTextCache.size() && !m_chapterPlainTextCache[s].isEmpty()) {
                    continue;
                }
            }

            const QString& chapterPath = m_spine[s].zipPath;
            if (!m_zipEntries.contains(chapterPath)) continue;

            QString plainText = extractPlainTextFromXml(m_zipEntries.value(chapterPath));

            {
                QMutexLocker locker(&m_textCacheMutex);
                if (m_indexingSessionId.load() != currentSession) return;
                if (s < m_chapterPlainTextCache.size()) {
                    m_chapterPlainTextCache[s] = std::move(plainText);
                }
            }

            QThread::msleep(5); // Cooperative yield
        }
    });
}

void EpubDocument::paginateDocument() {
    m_pageMappings.clear();
    m_spineStartPage.clear();

    {
        QMutexLocker locker(&m_textCacheMutex);
        m_chapterPlainTextCache.clear();
        m_chapterPlainTextCache.resize(m_spine.size());
    }

    int runningGlobalPage = 0;

    for (int s = 0; s < m_spine.size(); ++s) {
        const QString& path = m_spine[s].zipPath;
        m_spineStartPage.insert(path, runningGlobalPage);

        qint64 byteSize = m_zipEntries.value(path).size();
        int chapterPages = std::max<int>(1, static_cast<int>(std::ceil(static_cast<double>(byteSize) / BYTES_PER_SYNTHETIC_PAGE)));

        for (int p = 0; p < chapterPages; ++p) {
            EpubPageMapping mapping;
            mapping.spineIndex = s;
            mapping.pageInChapter = p;
            mapping.totalPagesInChapter = chapterPages;
            mapping.globalPageIndex = runningGlobalPage;
            m_pageMappings.append(mapping);
            runningGlobalPage++;
        }
    }

    m_totalPageNumber = m_pageMappings.size();
}

QImage EpubDocument::getPageImageData(int pageIndex) {
    QMutexLocker locker(&m_renderMutex); // Serializes QTextDocument layout across threads

    if (pageIndex < 0 || pageIndex >= m_totalPageNumber || pageIndex >= m_pageMappings.size()) {
        return QImage();
    }

    const EpubPageMapping& mapping = m_pageMappings[pageIndex];
    auto doc = getChapterDocument(mapping.spineIndex);
    if (!doc) {
        return QImage();
    }

    constexpr qreal scale = RENDER_DPI / 72.0;
    const int imgWidth = static_cast<int>(PAGE_WIDTH_POINTS * scale);
    const int imgHeight = static_cast<int>(PAGE_HEIGHT_POINTS * scale);

    QImage pageImage(imgWidth, imgHeight, QImage::Format_ARGB32_Premultiplied);
    pageImage.fill(Qt::white);

    QPainter painter(&pageImage);
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setRenderHint(QPainter::TextAntialiasing, true);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    painter.scale(scale, scale);

    qreal docHeight = std::max(PAGE_HEIGHT_POINTS, doc->size().height());
    int totalPages = std::max(1, mapping.totalPagesInChapter);
    qreal sliceHeight = docHeight / totalPages;
    qreal pageY = mapping.pageInChapter * sliceHeight;

    painter.save();
    painter.translate(0.0, -pageY);
    painter.setClipRect(QRectF(0.0, pageY, PAGE_WIDTH_POINTS, sliceHeight));

    QAbstractTextDocumentLayout::PaintContext ctx;
    ctx.clip = QRectF(0.0, pageY, PAGE_WIDTH_POINTS, sliceHeight);
    doc->documentLayout()->draw(&painter, ctx);

    painter.restore();
    return pageImage;
}

QList<TextRectItem> EpubDocument::getPageTextRects(int pageIndex) {
    QMutexLocker locker(&m_renderMutex); // Serializes QTextDocument word extraction

    if (pageIndex < 0 || pageIndex >= m_totalPageNumber || pageIndex >= m_pageMappings.size()) {
        return {};
    }

    const EpubPageMapping& mapping = m_pageMappings[pageIndex];
    auto doc = getChapterDocument(mapping.spineIndex);
    if (!doc) {
        return {};
    }

    return extractWordRectsForPage(doc.get(), mapping.pageInChapter, mapping.totalPagesInChapter);
}

QSizeF EpubDocument::getPageSizePoints(int pageIndex) {
    Q_UNUSED(pageIndex);
    return QSizeF(PAGE_WIDTH_POINTS, PAGE_HEIGHT_POINTS);
}

const QVector<TocItem>& EpubDocument::getTableOfContents() {
    return m_tableOfContents;
}

int EpubDocument::resolvePage(int pageNum, const QString &targetLocation) const {
    if (pageNum > 0) return pageNum;
    if (!targetLocation.isEmpty()) {
        QString pureFile = targetLocation.split('#').first();
        if (m_spineStartPage.contains(pureFile)) {
            return m_spineStartPage[pureFile] + 1;
        }
    }
    return 1;
}

int EpubDocument::resolvePage(const QVariantMap &item) const {
    int page = item.value("pageNum").toInt();
    QString target = item.value("targetLocation").toString();
    return resolvePage(page, target);
}

QList<QRectF> EpubDocument::searchPage(int pageIndex, const QString &text, bool matchCase, bool wholeWord) {
    if (text.trimmed().isEmpty() || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return {};
    }

    QList<TextRectItem> rects = getPageTextRects(pageIndex);
    QList<QRectF> matches;
    Qt::CaseSensitivity cs = matchCase ? Qt::CaseSensitive : Qt::CaseInsensitive;

    for (const auto& item : rects) {
        bool isMatch = wholeWord ? (item.text.compare(text, cs) == 0) : item.text.contains(text, cs);
        if (isMatch) {
            matches.append(QRectF(item.x, item.y, item.width, item.height));
        }
    }

    return matches;
}

QList<SearchResultItem> EpubDocument::searchDocument(const QString &text, bool matchCase, bool wholeWord) {
    Q_UNUSED(text);
    Q_UNUSED(matchCase);
    Q_UNUSED(wholeWord);
    return {};
}

void EpubDocument::cancelSearch() {
    m_activeSearchId.fetch_add(1);
}

void EpubDocument::startSearch(const QString &text, bool matchCase, bool wholeWord) {
    const uint64_t currentId = ++m_activeSearchId;
    const QString query = text.trimmed();

    if (query.isEmpty() || m_spine.isEmpty()) {
        emit searchResultsReady(text, {});
        return;
    }

    QThreadPool::globalInstance()->start([this, text, query, matchCase, wholeWord, currentId]() {
        QStringMatcher matcher(query, matchCase ? Qt::CaseSensitive : Qt::CaseInsensitive);
        QList<SearchResultItem> results;

        for (int s = 0; s < m_spine.size(); ++s) {
            if (m_activeSearchId.load() != currentId) return;

            QString plainText;
            {
                QMutexLocker locker(&m_textCacheMutex);
                if (s < m_chapterPlainTextCache.size()) {
                    plainText = m_chapterPlainTextCache[s];
                }
            }

            if (plainText.isEmpty()) {
                const QString& chapterPath = m_spine[s].zipPath;
                if (m_zipEntries.contains(chapterPath)) {
                    plainText = extractPlainTextFromXml(m_zipEntries.value(chapterPath));
                    QMutexLocker locker(&m_textCacheMutex);
                    if (s < m_chapterPlainTextCache.size()) {
                        m_chapterPlainTextCache[s] = plainText;
                    }
                }
            }

            if (plainText.isEmpty()) continue;

            const QString& chapterPath = m_spine[s].zipPath;
            int startPage = m_spineStartPage.value(chapterPath, 0);

            qsizetype from = 0;
            while (from < plainText.length()) {
                if (m_activeSearchId.load() != currentId) return;

                qsizetype matchIdx = matcher.indexIn(plainText, from);
                if (matchIdx == -1) break;

                bool valid = true;
                if (wholeWord) {
                    if (matchIdx > 0 && plainText.at(matchIdx - 1).isLetterOrNumber()) valid = false;
                    qsizetype endIdx = matchIdx + query.length();
                    if (endIdx < plainText.length() && plainText.at(endIdx).isLetterOrNumber()) valid = false;
                }

                if (valid) {
                    SearchResultItem item;
                    double ratio = plainText.length() > 0 ? (static_cast<double>(matchIdx) / plainText.length()) : 0.0;
                    int chapterSpan = std::max<int>(1, static_cast<int>(m_zipEntries.value(chapterPath).size() / BYTES_PER_SYNTHETIC_PAGE));
                    int pageInChapter = std::min(chapterSpan - 1, static_cast<int>(ratio * chapterSpan));

                    item.pageNum = startPage + pageInChapter + 1;

                    int snippetStart = std::max<int>(0, static_cast<int>(matchIdx) - 35);
                    int snippetEnd = std::min<int>(static_cast<int>(plainText.length()), static_cast<int>(matchIdx + query.length()) + 45);

                    QString before = plainText.mid(snippetStart, matchIdx - snippetStart);
                    before.replace(QLatin1Char('\n'), QLatin1Char(' '));
                    before.replace(QLatin1Char('\r'), QLatin1Char(' '));
                    item.textBefore = before.trimmed();

                    item.matchText = plainText.mid(matchIdx, query.length());

                    QString after = plainText.mid(matchIdx + query.length(), snippetEnd - (matchIdx + query.length()));
                    after.replace(QLatin1Char('\n'), QLatin1Char(' '));
                    after.replace(QLatin1Char('\r'), QLatin1Char(' '));
                    item.textAfter = after.trimmed();

                    results.append(std::move(item));
                }

                from = matchIdx + std::max<qsizetype>(1, query.length());
            }
        }

        if (m_activeSearchId.load() == currentId) {
            QMetaObject::invokeMethod(this, [this, text, results]() {
                emit searchResultsReady(text, results);
            }, Qt::QueuedConnection);
        }
    });
}

// --- ZIP Engine ---

QByteArray EpubDocument::decompressDeflate(const char* data, quint32 compressedSize, quint32 uncompressedSize) {
    if (compressedSize == 0 || uncompressedSize == 0 || !data || uncompressedSize > 100 * 1024 * 1024) {
        return QByteArray();
    }

    QByteArray output;
    output.resize(uncompressedSize);

    z_stream strm;
    std::memset(&strm, 0, sizeof(strm));
    strm.next_in = reinterpret_cast<Bytef*>(const_cast<char*>(data));
    strm.avail_in = compressedSize;
    strm.next_out = reinterpret_cast<Bytef*>(output.data());
    strm.avail_out = uncompressedSize;

    if (inflateInit2(&strm, -MAX_WBITS) != Z_OK) {
        return QByteArray();
    }

    int ret = inflate(&strm, Z_FINISH);
    inflateEnd(&strm);

    if (ret != Z_STREAM_END && ret != Z_OK) {
        return QByteArray();
    }

    return output;
}

QString EpubDocument::normalizeZipPath(const QString& rawPath) {
    QString p = rawPath;
    p.replace('\\', '/');
    while (p.startsWith('/')) p.remove(0, 1);
    return QDir::cleanPath(p);
}

QString EpubDocument::resolveRelativePath(const QString& basePath, const QString& relativePath) {
    if (relativePath.startsWith('/')) return normalizeZipPath(relativePath);
    return normalizeZipPath(basePath + "/" + relativePath);
}

bool EpubDocument::readZipArchive(const QString& localPath) {
    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) return false;

    const qint64 fileSize = file.size();
    if (fileSize < 22) return false;

    const qint64 maxTailSearch = std::min<qint64>(fileSize, 65557);
    file.seek(fileSize - maxTailSearch);
    const QByteArray tail = file.read(maxTailSearch);

    int eocdOffsetInTail = -1;
    for (int i = tail.size() - 22; i >= 0; --i) {
        if (static_cast<uchar>(tail[i]) == 0x50 &&
            static_cast<uchar>(tail[i + 1]) == 0x4b &&
            static_cast<uchar>(tail[i + 2]) == 0x05 &&
            static_cast<uchar>(tail[i + 3]) == 0x06) {
            eocdOffsetInTail = i;
            break;
        }
    }

    if (eocdOffsetInTail == -1) return false;

    const char* eocd = tail.constData() + eocdOffsetInTail;
    quint16 totalEntries = 0;
    quint32 cdOffset = 0;
    std::memcpy(&totalEntries, eocd + 10, sizeof(quint16));
    std::memcpy(&cdOffset, eocd + 16, sizeof(quint32));

    if (cdOffset >= fileSize) return false;
    if (!file.seek(cdOffset)) return false;

    for (quint16 i = 0; i < totalEntries; ++i) {
        char cdHeader[46];
        if (file.read(cdHeader, 46) != 46) break;
        if (std::memcmp(cdHeader, "\x50\x4b\x01\x02", 4) != 0) break;

        quint16 method = 0;
        quint32 compSize = 0;
        quint32 uncompSize = 0;
        quint16 nameLen = 0;
        quint16 extraLen = 0;
        quint16 commLen = 0;
        quint32 localOffset = 0;

        std::memcpy(&method, cdHeader + 10, 2);
        std::memcpy(&compSize, cdHeader + 20, 4);
        std::memcpy(&uncompSize, cdHeader + 24, 4);
        std::memcpy(&nameLen, cdHeader + 28, 2);
        std::memcpy(&extraLen, cdHeader + 30, 2);
        std::memcpy(&commLen, cdHeader + 32, 2);
        std::memcpy(&localOffset, cdHeader + 42, 4);

        QByteArray rawName = file.read(nameLen);
        QString fileName = normalizeZipPath(QString::fromUtf8(rawName));
        file.seek(file.pos() + extraLen + commLen);

        qint64 nextCdPos = file.pos();

        if (localOffset < fileSize && file.seek(localOffset)) {
            ZipLocalHeader locHeader;
            if (file.read(reinterpret_cast<char*>(&locHeader), sizeof(ZipLocalHeader)) == sizeof(ZipLocalHeader)) {
                if (locHeader.signature == 0x04034b50) {
                    qint64 dataOffset = localOffset + sizeof(ZipLocalHeader) + locHeader.fileNameLength + locHeader.extraFieldLength;
                    if (dataOffset < fileSize && file.seek(dataOffset)) {
                        QByteArray compressedData = file.read(compSize);
                        if (compressedData.size() == static_cast<int>(compSize)) {
                            if (method == 0) {
                                m_zipEntries.insert(fileName, compressedData);
                            } else if (method == 8) {
                                QByteArray decompressed = decompressDeflate(compressedData.constData(), compSize, uncompSize);
                                if (!decompressed.isEmpty() || uncompSize == 0) {
                                    m_zipEntries.insert(fileName, decompressed);
                                }
                            }
                        }
                    }
                }
            }
        }

        file.seek(nextCdPos);
    }

    return !m_zipEntries.isEmpty();
}

// --- EPUB XML Engine ---

bool EpubDocument::parseContainerXml() {
    const QString containerKey = "META-INF/container.xml";
    if (!m_zipEntries.contains(containerKey)) return false;

    QXmlStreamReader xml(m_zipEntries[containerKey]);
    QString opfPath;

    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();
        if (xml.isStartElement() && xml.name() == QLatin1String("rootfile")) {
            opfPath = xml.attributes().value("full-path").toString();
            if (!opfPath.isEmpty()) break;
        }
    }

    if (opfPath.isEmpty()) return false;
    return parseOpfFile(normalizeZipPath(opfPath));
}

bool EpubDocument::parseOpfFile(const QString& opfPath) {
    if (!m_zipEntries.contains(opfPath)) return false;

    int lastSlash = opfPath.lastIndexOf('/');
    m_opfDirectory = (lastSlash != -1) ? opfPath.left(lastSlash) : "";

    QXmlStreamReader xml(m_zipEntries[opfPath]);
    QString ncxId;
    QString navHref;

    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();

        if (xml.isStartElement()) {
            const QStringView tag = xml.name();

            if (tag == QLatin1String("title") && m_title.isEmpty()) {
                m_title = xml.readElementText().trimmed();
            } else if (tag == QLatin1String("item")) {
                const auto attrs = xml.attributes();
                QString id = attrs.value("id").toString();
                QString href = attrs.value("href").toString();
                QString properties = attrs.value("properties").toString();

                if (!id.isEmpty() && !href.isEmpty()) {
                    QString fullZipPath = resolveRelativePath(m_opfDirectory, href);
                    m_manifest.insert(id, fullZipPath);

                    if (properties.contains("nav")) navHref = fullZipPath;
                }
            } else if (tag == QLatin1String("spine")) {
                ncxId = xml.attributes().value("toc").toString();
            } else if (tag == QLatin1String("itemref")) {
                QString idref = xml.attributes().value("idref").toString();
                if (m_manifest.contains(idref)) {
                    EpubSpineItem item;
                    item.id = idref;
                    item.zipPath = m_manifest[idref];
                    m_spine.append(item);
                }
            }
        }
    }

    if (m_title.isEmpty()) {
        m_title = QFileInfo(m_fileUrl.toLocalFile()).completeBaseName();
    }

    if (m_spine.isEmpty()) return false;

    // Fast synthetic pagination
    paginateDocument();

    m_tableOfContents.clear();
    if (!ncxId.isEmpty() && m_manifest.contains(ncxId)) {
        parseTocNcx(m_manifest[ncxId], m_tableOfContents);
    } else if (!navHref.isEmpty()) {
        parseNavXhtml(navHref, m_tableOfContents);
    }

    if (m_tableOfContents.isEmpty()) {
        generateFallbackToc();
    }

    return true;
}

void EpubDocument::parseNavPoints(QXmlStreamReader& xml, const QString& ncxDir, QVector<TocItem>& outputList) {
    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();

        if (xml.isStartElement()) {
            if (xml.name() == QLatin1String("navPoint")) {
                TocItem node;
                node.pageNum = 1;

                while (!xml.atEnd()) {
                    xml.readNext();
                    if (xml.isStartElement()) {
                        if (xml.name() == QLatin1String("text") && node.title.isEmpty()) {
                            node.title = xml.readElementText().trimmed();
                        } else if (xml.name() == QLatin1String("content")) {
                            QString src = xml.attributes().value("src").toString();
                            node.targetLocation = resolveRelativePath(ncxDir, src);
                            QString pureFile = src.split('#').first();
                            QString target = resolveRelativePath(ncxDir, pureFile);
                            if (m_spineStartPage.contains(target)) {
                                node.pageNum = m_spineStartPage[target] + 1;
                            }
                        } else if (xml.name() == QLatin1String("navPoint")) {
                            xml.readNext();
                            QVector<TocItem> childList;
                            parseNavPoints(xml, ncxDir, childList);
                            node.TocItemChildren = childList;
                            node.hasChildren = !childList.isEmpty();
                            break;
                        }
                    } else if (xml.isEndElement() && xml.name() == QLatin1String("navPoint")) {
                        break;
                    }
                }

                if (!node.title.isEmpty()) {
                    outputList.append(node);
                }
            }
        } else if (xml.isEndElement() && xml.name() == QLatin1String("navMap")) {
            break;
        }
    }
}

void EpubDocument::parseTocNcx(const QString& ncxPath, QVector<TocItem>& tocList) {
    if (!m_zipEntries.contains(ncxPath)) return;

    int lastSlash = ncxPath.lastIndexOf('/');
    QString ncxDir = (lastSlash != -1) ? ncxPath.left(lastSlash) : "";

    QXmlStreamReader xml(m_zipEntries[ncxPath]);
    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();
        if (xml.isStartElement() && xml.name() == QLatin1String("navMap")) {
            parseNavPoints(xml, ncxDir, tocList);
            break;
        }
    }
}

void EpubDocument::parseNavXhtml(const QString& navPath, QVector<TocItem>& tocList) {
    if (!m_zipEntries.contains(navPath)) return;

    int lastSlash = navPath.lastIndexOf('/');
    QString navDir = (lastSlash != -1) ? navPath.left(lastSlash) : "";

    QXmlStreamReader xml(m_zipEntries[navPath]);
    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();
        if (xml.isStartElement() && xml.name() == QLatin1String("a")) {
            QString href = xml.attributes().value("href").toString();
            QString title = xml.readElementText().trimmed();

            if (!href.isEmpty() && !title.isEmpty()) {
                QString pureFile = href.split('#').first();
                QString target = resolveRelativePath(navDir, pureFile);

                TocItem item;
                item.title = title;
                item.targetLocation = resolveRelativePath(navDir, href);
                item.pageNum = m_spineStartPage.contains(target) ? (m_spineStartPage[target] + 1) : 1;
                item.hasChildren = false;
                tocList.append(item);
            }
        }
    }
}

void EpubDocument::generateFallbackToc() {
    m_tableOfContents.clear();
    for (int i = 0; i < m_spine.size(); ++i) {
        TocItem item;
        item.title = QString("Chapter %1").arg(i + 1);
        item.pageNum = m_spineStartPage.value(m_spine[i].zipPath, 0) + 1;
        item.targetLocation = m_spine[i].zipPath;
        item.hasChildren = false;
        m_tableOfContents.append(item);
    }
}

// Chapter layout loader using QMap<int, shared_ptr> (no dangling pointers on eviction)
std::shared_ptr<QTextDocument> EpubDocument::getChapterDocument(int spineIndex) {
    if (spineIndex < 0 || spineIndex >= m_spine.size()) return nullptr;

    if (m_chapterLayoutCache.contains(spineIndex)) {
        return m_chapterLayoutCache.value(spineIndex);
    }

    const QString& chapterPath = m_spine[spineIndex].zipPath;
    if (!m_zipEntries.contains(chapterPath)) return nullptr;

    int lastSlash = chapterPath.lastIndexOf('/');
    QString chapterDir = (lastSlash != -1) ? chapterPath.left(lastSlash) : "";

    auto doc = std::make_shared<EpubResourceDocument>(m_zipEntries, chapterDir);
    doc->setPageSize(QSizeF(PAGE_WIDTH_POINTS, PAGE_HEIGHT_POINTS));

    doc->setDefaultStyleSheet(
        "body { color: #111111; margin: 36px; font-family: sans-serif; font-size: 13pt; line-height: 1.55; }"
        "p { margin-top: 0.5em; margin-bottom: 0.5em; text-align: justify; }"
        "h1, h2, h3 { color: #000000; text-align: center; margin-top: 1em; margin-bottom: 0.5em; }"
        "img { max-width: 100%; height: auto; display: block; margin: auto; }"
        );

    QString htmlContent = QString::fromUtf8(m_zipEntries[chapterPath]);
    doc->setHtml(htmlContent);

    if (m_chapterLayoutCache.size() > 10) {
        m_chapterLayoutCache.remove(m_chapterLayoutCache.firstKey());
    }
    m_chapterLayoutCache.insert(spineIndex, doc);

    return doc;
}

QList<TextRectItem> EpubDocument::extractWordRectsForPage(QTextDocument* doc, int pageInChapter, int totalPagesInChapter) {
    QList<TextRectItem> result;
    if (!doc) return result;

    qreal docHeight = std::max(PAGE_HEIGHT_POINTS, doc->size().height());
    int totalPages = std::max(1, totalPagesInChapter);
    qreal sliceHeight = docHeight / totalPages;
    const qreal pageYStart = pageInChapter * sliceHeight;
    const qreal pageYEnd = (pageInChapter + 1) * sliceHeight;

    QAbstractTextDocumentLayout *layout = doc->documentLayout();
    if (!layout) return result;

    for (QTextBlock block = doc->begin(); block.isValid(); block = block.next()) {
        QRectF blockRect = layout->blockBoundingRect(block);
        if (blockRect.bottom() < pageYStart || blockRect.top() > pageYEnd) continue;

        QTextLayout *tl = block.layout();
        if (!tl) continue;

        QString text = block.text();
        if (text.trimmed().isEmpty()) continue;

        const int len = text.length();
        int wordStart = -1;

        for (int i = 0; i <= len; ++i) {
            bool isWordChar = (i < len) && !text.at(i).isSpace();
            if (isWordChar) {
                if (wordStart == -1) wordStart = i;
            } else {
                if (wordStart != -1) {
                    int wordLen = i - wordStart;
                    QString wordStr = text.mid(wordStart, wordLen);

                    QTextLine line = tl->lineForTextPosition(wordStart);
                    if (line.isValid()) {
                        qreal x1 = line.cursorToX(wordStart);
                        qreal x2 = line.cursorToX(wordStart + wordLen);

                        qreal left = std::min(x1, x2);
                        qreal right = std::max(x1, x2);
                        qreal width = right - left;

                        qreal absY = blockRect.top() + line.y();
                        qreal height = line.height();

                        if (absY + height > pageYStart && absY < pageYEnd) {
                            TextRectItem item;
                            item.text = wordStr;
                            item.x = left;
                            item.y = absY - pageYStart;
                            item.width = width;
                            item.height = height;
                            result.append(std::move(item));
                        }
                    }
                    wordStart = -1;
                }
            }
        }
    }

    return result;
}