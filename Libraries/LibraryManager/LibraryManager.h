#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantMap>
#include <QVariantList>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <memory>

class DocumentBase;

struct BookmarkRecord {
    int page = 1;
    QString title;
    qint64 createdAt = 0;

    QJsonObject toJson() const;
    static BookmarkRecord fromJson(const QJsonObject& json);
    QVariantMap toVariantMap() const;
};

struct DocumentRecord {
    QString fingerprint;
    QString filePath;
    QString title;
    qint64 fileSize = 0;
    qint64 lastOpenedTimestamp = 0;
    int currentPage = 1;
    int totalPages = 0;
    qreal zoom = 1.0;
    qreal rotation = 0.0;
    bool isActivelyReading = false;
    bool isFavorite = false;
    QString thumbnailPath;
    QList<BookmarkRecord> bookmarks;

    QJsonObject toJson() const;
    static DocumentRecord fromJson(const QJsonObject& json);
    QVariantMap toVariantMap() const;
};

class LibraryManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantMap lastReadDocument READ getLastReadDocument NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList activelyReadingList READ getActivelyReadingList NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList favoritesList READ getFavoritesList NOTIFY libraryChanged)

public:
    explicit LibraryManager(QObject* parent = nullptr);
    ~LibraryManager() override = default;

    // Fast Composite Hash (First 64 KB + File Size)
    Q_INVOKABLE QString computeFingerprint(const QString& localPath) const;

    // Document Session Tracking
    Q_INVOKABLE void recordDocumentOpened(DocumentBase* doc);
    Q_INVOKABLE void updateSessionState(DocumentBase* doc, int currentPage, qreal zoom, qreal rotation);

    // Queries
    Q_INVOKABLE QVariantMap getLastReadDocument() const;
    Q_INVOKABLE QVariantList getActivelyReadingList() const;
    Q_INVOKABLE QVariantList getFavoritesList() const;
    Q_INVOKABLE QVariantList getBookmarks(const QString& fingerprint) const;
    Q_INVOKABLE bool checkFileExists(const QString& filePath) const;

    // Mutators
    Q_INVOKABLE void toggleFavorite(const QString& fingerprint);
    Q_INVOKABLE void markAsFinished(const QString& fingerprint);
    Q_INVOKABLE void addBookmark(const QString& fingerprint, int page, const QString& title);
    Q_INVOKABLE void removeBookmark(const QString& fingerprint, int page);
    Q_INVOKABLE void removeDocumentRecord(const QString& fingerprint);

    //used for getting bookmarks for document
    Q_INVOKABLE QString getDocumentFingerprint(DocumentBase* doc) const;
    Q_INVOKABLE bool isFavorite(const QString& fingerprint) const;
    Q_INVOKABLE bool isDocumentFavorite(DocumentBase* doc) const;

signals:
    void libraryChanged();
    void requestOpenDocument(const QString& filePath, int page, qreal zoom, qreal rotation);

private:
    void loadLibrary();
    void saveLibrary();
    QString getThumbnailFilePath(const QString& fingerprint) const;
    void generateThumbnailIfMissing(DocumentBase* doc, const QString& fingerprint);

private:
    QString m_libraryFilePath;
    QString m_thumbnailsDirectory;
    QString m_lastReadFingerprint;
    QMap<QString, DocumentRecord> m_records; // Keyed by document fingerprint
};