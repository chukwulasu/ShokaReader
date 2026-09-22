#pragma once

#include <memory>
#include <poppler/qt6/poppler-qt6.h>
#include "Libraries/DocumentManager/DocumentBase.h"

class PdfDocument : public DocumentBase {
    Q_OBJECT

public:
    explicit PdfDocument(QObject* parent = nullptr);
    ~PdfDocument() override;
    void getDocumentMetaData(const QUrl& filePath) override;
    QImage renderPageImage(int pageIndex, const QSize& targetSize) override;
    QVariantList getTableOfContents() override;
    Q_INVOKABLE QVariantList getPageTextRects(int pageIndex) override;
    Q_INVOKABLE QSizeF getPageSizePoints(int pageIndex) override;

private:
    DocumentBase::TocItem parsePopplerToc(const Poppler::OutlineItem* item, Poppler::Document* pdfDoc);

private:
    std::unique_ptr<Poppler::Document> m_pdfDocument = nullptr;
};