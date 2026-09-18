#include <QFileInfo>
#include <QDebug>
#include "Libraries/DocumentManager/PdfDocument.h"

PdfDocument::PdfDocument(QObject* parent)
    : DocumentBase(parent) {}

PdfDocument::~PdfDocument() = default;

void PdfDocument::getDocumentMetaData(const QUrl& filePath) {
    m_fileUrl = filePath;
    QString localPath = filePath.toLocalFile();

    m_pdfDocument = Poppler::Document::load(localPath);
    // TODO: write code to provide dialog to unlokck locked pdf files
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() == true) {
        qWarning() << "[PdfDocument] Failed to load PDF file with Poppler:" << localPath;
        m_totalPageNumber = 0;
        m_title.clear();
        m_pdfDocument.reset();
    } else {     
        m_totalPageNumber = m_pdfDocument->numPages();
        m_title = QFileInfo(localPath).completeBaseName();
        qDebug() << "[PdfDocument] Successfully loaded PDF with Poppler. Total pages:" << m_totalPageNumber;
    }
}

QImage PdfDocument::renderPageImage(int pageIndex, const QSize& targetSize) {
    if (m_pdfDocument == nullptr || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return QImage();
    }

    std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(pageIndex));
    if (pdfPage == nullptr) {
        return QImage();
    }
    return pdfPage->renderToImage(250, 250,targetSize.width(),targetSize.height());
}