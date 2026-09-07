#include <QFileInfo>
#include <QDebug>
#include "Libraries/DocumentManager/PdfDocument.h"

PdfDocument::PdfDocument(QObject* parent)
    : DocumentBase(parent) {}

PdfDocument::~PdfDocument() = default;

void PdfDocument::getDocumentMetaData(const QUrl& filePath) {
    m_sourceUrl = filePath;
    QString localPath = filePath.toLocalFile();

    QPdfDocument::Error err = m_pdfDocument.load(localPath);
    if (err == QPdfDocument::Error::None) {
        m_totalPageNumber = m_pdfDocument.pageCount();
        m_currentPageNumber = 0;
        m_title = QFileInfo(localPath).fileName();
        qDebug() << "[PdfDocument] Successfully loaded PDF. Total pages:" << m_totalPageNumber;
    } else {
        qWarning() << "[PdfDocument] Failed to load PDF file. Error code:" << static_cast<int>(err);
        m_totalPageNumber = 0;
        m_title.clear();
    }
}

QImage PdfDocument::renderPageImage(int pageIndex, const QSize& targetSize) {
    if (pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return QImage();
    }
    return m_pdfDocument.render(pageIndex, targetSize);
}

QSizeF PdfDocument::nativePageSize(int pageIndex) const {
    if (pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return QSizeF(0, 0);
    }
    return m_pdfDocument.pagePointSize(pageIndex);
}
