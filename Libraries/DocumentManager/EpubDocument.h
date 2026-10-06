#pragma once

#include <memory>
#include <atomic>
#include <QVector>
#include <QMap>
#include <QStringList>
#include <QByteArray>
#include <QTextDocument>
#include <QMutex>
#include <QXmlStreamReader>
#include "Libraries/DocumentManager/DocumentBase.h"

struct EpubSpineItem {
    QString id;
    QString zipPath;
};

struct EpubPageMapping {
    int spineIndex = 0;
    int pageInChapter = 0;
    int totalPagesInChapter = 1;
    int globalPageIndex = 0;
};

class EpubDocument : public DocumentBase {
    Q_OBJECT

public:
    explicit EpubDocument(QObject* parent = nullptr);
    ~EpubDocument() override;

    DocumentState getDocumentMetaData(const QUrl& filePath) override;
    bool unlock(const QString& userPassword, const QString& ownerPassword = QString()) override;
    QImage getPageImageData(int pageIndex) override;
    const QVector<TocItem>& getTableOfContents() override;

    Q_INVOKABLE QList<TextRectItem> getPageTextRects(int pageIndex) override;
    Q_INVOKABLE QSizeF getPageSizePoints(int pageIndex) override;
    Q_INVOKABLE QList<QRectF> searchPage(int pageIndex, const QString &text, bool matchCase = false, bool wholeWord = false) override;
    Q_INVOKABLE QList<SearchResultItem> searchDocument(const QString &text, bool matchCase = false, bool wholeWord = false) override;

    // Asynchronous Background Search
    Q_INVOKABLE void startSearch(const QString &text, bool matchCase = false, bool wholeWord = false) override;
    Q_INVOKABLE void cancelSearch() override;

    int resolvePage(int pageNum, const QString &targetLocation = QString()) const override;
    int resolvePage(const QVariantMap &item) const override;

private:
    bool readZipArchive(const QString& localPath);
    static QByteArray decompressDeflate(const char* data, quint32 compressedSize, quint32 uncompressedSize);
    static QString normalizeZipPath(const QString& rawPath);
    static QString resolveRelativePath(const QString& basePath, const QString& relativePath);
    static QString extractPlainTextFromXml(const QByteArray& xmlData);

    bool parseContainerXml();
    bool parseOpfFile(const QString& opfPath);
    void parseTocNcx(const QString& ncxPath, QVector<TocItem>& tocList);
    void parseNavPoints(QXmlStreamReader& xml, const QString& ncxDir, QVector<TocItem>& outputList);
    void parseNavXhtml(const QString& navPath, QVector<TocItem>& tocList);
    void generateFallbackToc();

    // High-speed synthetic pagination (<3 ms)
    void paginateDocument();
    std::shared_ptr<QTextDocument> getChapterDocument(int spineIndex);
    QList<TextRectItem> extractWordRectsForPage(QTextDocument* doc, int pageInChapter, int totalPagesInChapter);

    // Background Text Indexer
    void startBackgroundTextIndexing();
    void cancelBackgroundIndexing();

private:
    QMap<QString, QByteArray> m_zipEntries;
    QString m_opfDirectory;
    QVector<EpubSpineItem> m_spine;
    QMap<QString, QString> m_manifest;
    QMap<QString, int> m_spineStartPage;
    QVector<EpubPageMapping> m_pageMappings;

    // In-memory plain text cache for background search
    QVector<QString> m_chapterPlainTextCache;

    // Thread-safe map cache avoiding QCache eviction deletion bugs
    mutable QMap<int, std::shared_ptr<QTextDocument>> m_chapterLayoutCache;
    mutable QMutex m_renderMutex;
    mutable QMutex m_textCacheMutex;

    std::atomic<uint64_t> m_activeSearchId{0};
    std::atomic<uint64_t> m_indexingSessionId{0};

    static constexpr qreal PAGE_WIDTH_POINTS = 595.0;
    static constexpr qreal PAGE_HEIGHT_POINTS = 842.0;
    static constexpr double RENDER_DPI = 180.0;
    static constexpr int BYTES_PER_SYNTHETIC_PAGE = 1800;
};