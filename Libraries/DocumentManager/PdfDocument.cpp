#include <QFileInfo>
#include <QDebug>
#include "Libraries/DocumentManager/PdfDocument.h"

PdfDocument::PdfDocument(QObject* parent)
    : DocumentBase(parent) {}

PdfDocument::~PdfDocument() = default;

bool PdfDocument::getDocumentMetaData(const QUrl& filePath) {
    m_fileUrl = filePath;
    QString localPath = filePath.toLocalFile();

    m_pdfDocument = Poppler::Document::load(localPath);
    // TODO: write code to provide dialog to unlokck locked pdf files
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() == true) {
        m_totalPageNumber = 0;
        m_title.clear();
        m_pdfDocument.reset();
        return false;
    } else {     
        m_totalPageNumber = m_pdfDocument->numPages();
        m_title = QFileInfo(localPath).completeBaseName();
        // Notify QML that the table of contents data is now available
        emit tableOfContentsChanged();
    }
    return true;
}

QImage PdfDocument::getPageImageData(int pageIndex) {
    if (m_pdfDocument == nullptr || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return QImage();
    }

    std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(pageIndex));
    if (pdfPage == nullptr) {
        return QImage();
    }

    constexpr double renderDpi = 180.0; // 180 DPI gave the best result so don't change it

    return pdfPage->renderToImage(renderDpi, renderDpi);
}

QVariantList PdfDocument::getPageTextRects(int pageIndex) {
    QVariantList rectsList;
    if (m_pdfDocument == nullptr || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return rectsList;
    }

    std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(pageIndex));
    if (pdfPage == nullptr) {
        return rectsList;
    }

    std::vector<std::unique_ptr<Poppler::TextBox>> textBoxList = pdfPage->textList();
    for (const auto& textRect : textBoxList) {
        if (textRect == nullptr){
            continue;
        }

        QVariantMap wordMap;
        wordMap["text"] = textRect->text();

        QRectF rect = textRect->boundingBox();
        wordMap["x"] = rect.x();
        wordMap["y"] = rect.y();
        wordMap["width"] = rect.width();
        wordMap["height"] = rect.height();

        rectsList.append(wordMap);
    }

    return rectsList;
}

QSizeF PdfDocument::getPageSizePoints(int pageIndex) {
    if (m_pdfDocument == nullptr || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return QSizeF(0, 0);
    }
    std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(pageIndex));
    if (pdfPage == nullptr) {
        return QSizeF(0, 0);
    }
    return pdfPage->pageSizeF();
}

QVariantMap PdfDocument::toVariantMap(const TocItem& item) const {
    QVariantList childList;
    for (const auto& child : item.TocItemChildren) {
        childList.append(toVariantMap(child));
    }
    return QVariantMap{
        {"title", item.title},
        {"pageNum", item.pageNum},
        {"hasChildren", item.hasChildren},
        {"children", childList}
    };
}

DocumentBase::TocItem PdfDocument::parsePopplerToc(const Poppler::OutlineItem* item, Poppler::Document* pdfDoc) {
    DocumentBase::TocItem tocNode;
    if (item == nullptr){
         return tocNode;
    }

    tocNode.title = item->name();

    if (item->destination() != nullptr) {
        QSharedPointer<const Poppler::LinkDestination> dest = item->destination();
        tocNode.pageNum = dest->pageNumber();
    }

    const QVector<Poppler::OutlineItem> tocNodeChildren = item->children();
    tocNode.hasChildren = !tocNodeChildren.isEmpty();

    for (const auto& child : tocNodeChildren) {
        tocNode.TocItemChildren.append(parsePopplerToc(&child, pdfDoc));
    }

    return tocNode;
}

QVariantList PdfDocument::getTableOfContents() {
    if (!m_pdfDocument){
        return QVariantList();
    }

    QVector<Poppler::OutlineItem> outlineItems = m_pdfDocument->outline();
    QVariantList rootList;

    for (const auto& item : std::as_const(outlineItems)) {
        DocumentBase::TocItem node = parsePopplerToc(&item, m_pdfDocument.get());
        rootList.append(toVariantMap(node));
    }
    return rootList;
}