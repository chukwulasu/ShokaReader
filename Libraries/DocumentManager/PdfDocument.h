#pragma once

#include <memory>
#include <atomic>
#include <QVector>
#include <QMutex>
#include <poppler/qt6/poppler-qt6.h>
#include "Libraries/DocumentManager/DocumentBase.h"

class PdfDocument : public DocumentBase {
    Q_OBJECT

public:
    explicit PdfDocument(QObject* parent = nullptr);
    ~PdfDocument() override;

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

private:
    void parsePopplerToc(const QVector<Poppler::OutlineItem>& items, QVector<TocItem>& tocVector, int currentDepth = 0);
    void updatePermissions();

    void startBackgroundTextIndexing();
    void cancelBackgroundIndexing();

private:
    std::unique_ptr<Poppler::Document> m_pdfDocument = nullptr;

    mutable QMutex m_docMutex;
    mutable QMutex m_cacheMutex;
    std::atomic<uint64_t> m_activeSearchId{0};
    std::atomic<uint64_t> m_indexingSessionId{0};

    QVector<QString> m_pageTextCache;
};