#pragma once

#include <QPdfDocument>
#include "Libraries/DocumentManager/DocumentBase.h"

class PdfDocument : public DocumentBase {
    Q_OBJECT

public:
    explicit PdfDocument(QObject* parent = nullptr);
    ~PdfDocument() override;

    void getDocumentMetaData(const QUrl& filePath) override;
    QImage renderPageImage(int pageIndex, const QSize& targetSize) override;
    QSizeF nativePageSize(int pageIndex) const override;

private:
    QPdfDocument m_pdfDocument;
};