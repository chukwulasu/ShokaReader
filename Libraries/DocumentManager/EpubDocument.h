#pragma once

#include <memory>
#include <atomic>
#include <QVector>
#include <QMap>
#include <QStringList>
#include <QByteArray>
#include <QTextDocument>
#include <QCache>
#include <QMutex>
#include <QXmlStreamReader>
#include "Libraries/DocumentManager/DocumentBase.h"

struct EpubSpineItem {
    QString id;
    QString zipPath; // Normalized path inside the EPUB zip container
};

struct EpubPageMapping {
    int spineIndex = 0;       // Index into m_spine
    int pageInChapter = 0;    // 0-indexed page inside this chapter's layout
    int globalPageIndex = 0;  // 0-indexed global document page
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

    // Asynchronous Background Search API
    Q_INVOKABLE void startSearch(const QString &text, bool matchCase = false, bool wholeWord = false) override;
    Q_INVOKABLE void cancelSearch() override;

private:
    // --- In-Memory ZIP Archive Helpers ---
    bool readZipArchive(const QString& localPath);
    static QByteArray decompressDeflate(const char* data, quint32 compressedSize, quint32 uncompressedSize);
    static QString normalizeZipPath(const QString& rawPath);
    static QString resolveRelativePath(const QString& basePath, const QString& relativePath);

    // --- EPUB XML Parsing Helpers (Direct TocItem Streaming) ---
    bool parseContainerXml();
    bool parseOpfFile(const QString& opfPath);
    void parseTocNcx(const QString& ncxPath, QVector<TocItem>& tocList);
    void parseNavPoints(QXmlStreamReader& xml, const QString& ncxDir, QVector<TocItem>& outputList);
    void parseNavXhtml(const QString& navPath, QVector<TocItem>& tocList);
    void generateFallbackToc();

    // --- Pagination & Layout Helpers ---
    void paginateDocument();
    std::shared_ptr<QTextDocument> getChapterDocument(int spineIndex);
    QList<TextRectItem> extractWordRectsForPage(QTextDocument* doc, int pageInChapter);

private:
    // Extracted in-memory container files: [normalized internal path -> raw uncompressed data]
    QMap<QString, QByteArray> m_zipEntries;

    QString m_opfDirectory;
    QVector<EpubSpineItem> m_spine;
    QMap<QString, QString> m_manifest; // [id -> resolved zipPath]
    QMap<QString, int> m_spineStartPage; // [zipPath -> first global page index (0-based)]
    QVector<EpubPageMapping> m_pageMappings;

    // Plain text cache per chapter for high-speed Boyer-Moore search
    QVector<QString> m_chapterPlainTextCache;

    // LRU Cache for parsed chapter layouts (keeps up to 10 active chapters)
    mutable QCache<int, QTextDocument> m_chapterLayoutCache;
    mutable QMutex m_layoutMutex;

    // Concurrency control for background search
    std::atomic<uint64_t> m_activeSearchId{0};

    // Standard typographic dimensions in points (A4/A5 proportional: 595 x 842 pt)
    static constexpr qreal PAGE_WIDTH_POINTS = 595.0;
    static constexpr qreal PAGE_HEIGHT_POINTS = 842.0;
    static constexpr double RENDER_DPI = 180.0;
};