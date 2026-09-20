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
        // Notify QML that the table of contents data is now available
        emit tableOfContentsChanged();
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
    return pdfPage->renderToImage(120, 120,targetSize.width(),targetSize.height());
}

// Recursive helper function to parse Poppler's TOC tree
DocumentBase::TocItem PdfDocument::parsePopplerToc(const Poppler::OutlineItem* item, Poppler::Document* pdfDoc) {
    DocumentBase::TocItem tocNode;
    if (!item) return tocNode;

    tocNode.title = item->name();

    // Resolve destination directly
    if (item->destination()) {
        auto dest = item->destination();
        tocNode.pageNum = dest->pageNumber();
    }

    // Process nested subsections - note it returns a QList<Poppler::OutlineItem> by value
    const QList<Poppler::OutlineItem> children = item->children();
    tocNode.hasChildren = !children.isEmpty();

    // Loop through them using a const reference to avoid pointer mismatches
    for (const auto& child : children) {
        tocNode.children.append(parsePopplerToc(&child, pdfDoc));
    }

    return tocNode;
}

QVariantList PdfDocument::getTableOfContents() {
    if (!m_pdfDocument) return QVariantList();

    QVector<Poppler::OutlineItem> outlineItems = m_pdfDocument->outline();
    qDebug() << "[PdfDocument] Raw outline items found by Poppler:" << outlineItems.size();

    QVariantList rootList;
    for (const auto& item : std::as_const(outlineItems)) {
        DocumentBase::TocItem node = parsePopplerToc(&item, m_pdfDocument.get());
        rootList.append(toVariantMap(node));
    }

    qDebug() << "[PdfDocument] Total root TOC items serialized:" << rootList.size();
    return rootList;
}