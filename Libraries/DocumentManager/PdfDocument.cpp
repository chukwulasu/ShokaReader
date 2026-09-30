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
        m_tableOfContents.clear();
        return false;
    } else {     
        m_totalPageNumber = m_pdfDocument->numPages();
        m_title = QFileInfo(localPath).completeBaseName();
        m_tableOfContents.clear();
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

    constexpr double renderDpi = 180.0; // 180 DPI gave the best result for performacne and resolution so don't change it

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

const QVector<TocItem>& PdfDocument::getTableOfContents() {
    if (m_tableOfContents.isEmpty() == true  && m_pdfDocument != nullptr) {
        parsePopplerToc(m_pdfDocument->outline(), m_tableOfContents,0);
    }
    return m_tableOfContents;
}

void PdfDocument::parsePopplerToc(const QVector<Poppler::OutlineItem>& items, QVector<TocItem>& tocVector, int currentDepth) {
    constexpr int MAX_TOC_DEPTH = 4;

    if (items.isEmpty() == true || currentDepth >= MAX_TOC_DEPTH) {
        return;
    }

    tocVector.reserve(items.size());

    for (const auto& item : items) {
        TocItem tocNode;
        tocNode.title = item.name();

        if (auto dest = item.destination()) {
            tocNode.pageNum = dest->pageNumber();
        }

        const QVector<Poppler::OutlineItem> tocNodeChildren = item.children();
        tocNode.hasChildren = (tocNodeChildren.isEmpty() == false) && ((currentDepth + 1) < MAX_TOC_DEPTH);

        if (tocNode.hasChildren == true) {
            parsePopplerToc(tocNodeChildren, tocNode.TocItemChildren, currentDepth + 1);
        }

        tocVector.append(std::move(tocNode));
    }
}