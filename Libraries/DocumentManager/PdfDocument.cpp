#include <QFileInfo>
#include <QDebug>
#include <algorithm>
#include "Libraries/DocumentManager/PdfDocument.h"

PdfDocument::PdfDocument(QObject* parent)
    : DocumentBase(parent) {}

PdfDocument::~PdfDocument() = default;

DocumentState PdfDocument::getDocumentMetaData(const QUrl& filePath) {
    m_cachedUserPassword.clear();
    m_fileUrl = filePath;
    QString localPath = filePath.toLocalFile();

    m_pdfDocument = Poppler::Document::load(localPath);
    // TODO: write code to provide dialog to unlokck locked pdf files
    if (m_pdfDocument == nullptr) {
        m_totalPageNumber = 0;
        m_title.clear();
        m_tableOfContents.clear();
        return DocumentState::LoadFailed;
    }

    m_title = QFileInfo(localPath).completeBaseName();

    if (m_pdfDocument->isLocked() == true) {
        m_totalPageNumber = 0;
        m_tableOfContents.clear();
        return DocumentState::Locked;
    }

    m_totalPageNumber = m_pdfDocument->numPages();
    m_tableOfContents.clear();
    updatePermissions();
    return DocumentState::LoadSuccessful;
}

bool PdfDocument::unlock(const QString& password) {
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() == false) {
        return false;
    }

    m_cachedUserPassword = password;
    QByteArray passBytes = password.toUtf8();

    // Attempt to unlock with the provided password
    m_pdfDocument->unlock(passBytes, passBytes);

    if (m_pdfDocument->isLocked() == true) {
        m_pdfDocument->unlock(QByteArray(), passBytes);
    }

    if (m_pdfDocument->isLocked() == true) {
        m_pdfDocument->unlock(passBytes, QByteArray());
    }

    // Verify whether Poppler decrypted the document
    if (m_pdfDocument->isLocked() == false) {
        m_totalPageNumber = m_pdfDocument->numPages();
        m_tableOfContents.clear();
        updatePermissions();
        return true;
    }

    return false;
}

bool PdfDocument::unlockPermissions(const QString& ownerPassword) {
    if (m_pdfDocument == nullptr) {
        return false;
    }

    QString localPath = m_fileUrl.toLocalFile();
    QByteArray ownerBytes = ownerPassword.toUtf8();

    std::unique_ptr<Poppler::Document> reloadedDoc = Poppler::Document::load(localPath, ownerBytes, QByteArray());

    if ((reloadedDoc == nullptr || reloadedDoc->isLocked() == true || reloadedDoc->okToCopy() == false) && m_cachedUserPassword.isEmpty() == false) {
        reloadedDoc = Poppler::Document::load(localPath, ownerBytes, m_cachedUserPassword.toUtf8());
    }

    if (reloadedDoc == nullptr || reloadedDoc->isLocked() == true || reloadedDoc->okToCopy() == false) {
        reloadedDoc = Poppler::Document::load(localPath, ownerBytes, ownerBytes);
    }

    if (reloadedDoc != nullptr && reloadedDoc->isLocked() == false && reloadedDoc->okToCopy() == true) {
        m_pdfDocument = std::move(reloadedDoc);
        m_totalPageNumber = m_pdfDocument->numPages();
        updatePermissions();
        return true;
    }

    return false;
}

void PdfDocument::updatePermissions() {
    if (m_pdfDocument != nullptr && m_pdfDocument->isLocked() == false) {
        bool allowed = m_pdfDocument->okToCopy();
        qDebug() << "[Permissions] okToCopy allowed by document:" << allowed;
        if (m_canCopy != allowed) {
            m_canCopy = allowed;
            emit permissionsChanged();
        }
    }
}

QImage PdfDocument::getPageImageData(int pageIndex) {
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() == true || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return QImage();
    }

    std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(pageIndex));
    if (pdfPage == nullptr) {
        return QImage();
    }

    constexpr double renderDpi = 180.0; // 180 DPI gave the best result for performacne and resolution so don't change it

    return pdfPage->renderToImage(renderDpi, renderDpi);
}

QList<TextRectItem> PdfDocument::getPageTextRects(int pageIndex) {
    QList<TextRectItem> rectsList;
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() == true || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return rectsList;
    }

    std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(pageIndex));
    if (pdfPage == nullptr) {
        return rectsList;
    }

    std::vector<std::unique_ptr<Poppler::TextBox>> textBoxList = pdfPage->textList();
    if (textBoxList.empty()) {
        return rectsList;
    }

    // Filter out null elements before sorting
    textBoxList.erase(
        std::remove_if(textBoxList.begin(), textBoxList.end(),
                       [](const std::unique_ptr<Poppler::TextBox>& ptr) { return ptr == nullptr; }),
        textBoxList.end()
        );

    // Sort words into reading layout order (top-to-bottom, left-to-right)
    std::stable_sort(textBoxList.begin(), textBoxList.end(),
                     [](const std::unique_ptr<Poppler::TextBox>& a, const std::unique_ptr<Poppler::TextBox>& b) {
                         QRectF rectA = a->boundingBox();
                         QRectF rectB = b->boundingBox();

                         qreal overlapTop = std::max(rectA.top(), rectB.top());
                         qreal overlapBottom = std::min(rectA.bottom(), rectB.bottom());
                         qreal overlap = std::max<qreal>(0.0, overlapBottom - overlapTop);
                         qreal minHeight = std::min(rectA.height(), rectB.height());

                         // If vertical overlap is >= 50% of the smaller box's height, consider them on the same line
                         if (minHeight > 0.0 && overlap >= minHeight * 0.5) {
                             return rectA.left() < rectB.left();
                         }

                         // Otherwise, sort vertically top-to-bottom
                         return rectA.top() < rectB.top();
                     }
                     );

    rectsList.reserve(static_cast<qsizetype>(textBoxList.size()));

    for (const auto& textRect : textBoxList) {
        TextRectItem wordItem;
        wordItem.text = textRect->text();

        QRectF rect = textRect->boundingBox();
        wordItem.x = rect.x();
        wordItem.y = rect.y();
        wordItem.width = rect.width();
        wordItem.height = rect.height();

        rectsList.append(std::move(wordItem));
    }

    return rectsList;
}

QSizeF PdfDocument::getPageSizePoints(int pageIndex) {
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() == true || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return QSizeF(0, 0);
    }
    std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(pageIndex));
    if (pdfPage == nullptr) {
        return QSizeF(0, 0);
    }
    return pdfPage->pageSizeF();
}

const QVector<TocItem>& PdfDocument::getTableOfContents() {
    if (m_tableOfContents.isEmpty() == true && m_pdfDocument != nullptr && m_pdfDocument->isLocked() == false) {
        parsePopplerToc(m_pdfDocument->outline(), m_tableOfContents, 0);
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