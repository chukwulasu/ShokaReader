#pragma once

#include <memory>
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

    /*
    Returns a contiguous QList of TextRectItem structs holding
    the text string and bounding box in PDF points for each word.
    */
    Q_INVOKABLE QList<TextRectItem> getPageTextRects(int pageIndex) override;

    /*
    Returns the dimensions of page at pageIndex in points(i.e 1/72 th of an inch)
    */
    Q_INVOKABLE QSizeF getPageSizePoints(int pageIndex) override;

    /*
    Searches a specific page for text using Poppler's search routine.
    */
    Q_INVOKABLE QList<QRectF> searchPage(int pageIndex, const QString &text, bool matchCase = false, bool wholeWord = false) override;

    /*
    Searches the entire document and returns snippets with page numbers.
    */
    Q_INVOKABLE QList<SearchResultItem> searchDocument(const QString &text, bool matchCase = false, bool wholeWord = false) override;

private:
    // Recursive helper functions to parse Poppler's TOC tree
    void parsePopplerToc(const QVector<Poppler::OutlineItem>& items, QVector<TocItem>& tocVector, int currentDepth = 0);
    void updatePermissions();

private:
    std::unique_ptr<Poppler::Document> m_pdfDocument = nullptr;
};