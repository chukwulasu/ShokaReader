#include <QFileInfo>
#include <QDebug>
#include <QLineF>
#include <algorithm>
#include "Libraries/DocumentManager/PdfDocument.h"

PdfDocument::PdfDocument(QObject* parent)
    : DocumentBase(parent) {}

PdfDocument::~PdfDocument() = default;

DocumentState PdfDocument::getDocumentMetaData(const QUrl& filePath) {
    m_fileUrl = filePath;
    QString localPath = filePath.toLocalFile();

    m_pdfDocument = Poppler::Document::load(localPath);
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

bool PdfDocument::unlock(const QString& userPassword, const QString& ownerPassword) {
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() == false) {
        return false;
    }

    QByteArray userBytes = userPassword.toUtf8();
    QByteArray ownerBytes = ownerPassword.toUtf8();

    if (ownerBytes.isEmpty() == false && userBytes.isEmpty() == false) {
        m_pdfDocument->unlock(ownerBytes, userBytes);
    }

    if (m_pdfDocument->isLocked() == true && userBytes.isEmpty() == false) {
        m_pdfDocument->unlock(QByteArray(), userBytes);
    }

    if (m_pdfDocument->isLocked() == true && ownerBytes.isEmpty() == false) {
        m_pdfDocument->unlock(ownerBytes, QByteArray());
    }

    if (m_pdfDocument->isLocked() == true) {
        m_pdfDocument->unlock(userBytes, userBytes);
    }

    if (m_pdfDocument->isLocked() == false) {
        m_totalPageNumber = m_pdfDocument->numPages();
        m_tableOfContents.clear();
        updatePermissions();
        return true;
    }

    return false;
}

void PdfDocument::updatePermissions() {
    if (m_pdfDocument != nullptr && m_pdfDocument->isLocked() == false) {
        m_canCopy = m_pdfDocument->okToCopy();
    }
}

QList<QRectF> PdfDocument::searchPage(int pageIndex, const QString &text, bool matchCase, bool wholeWord) {
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() || text.trimmed().isEmpty() || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return {};
    }

    std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(pageIndex));
    if (pdfPage == nullptr) {
        return {};
    }

    Poppler::Page::SearchFlags flags;
    if (!matchCase) {
        flags |= Poppler::Page::IgnoreCase;
    }
    if (wholeWord) {
        flags |= Poppler::Page::WholeWords;
    }

    return pdfPage->search(text, flags);
}

QList<SearchResultItem> PdfDocument::searchDocument(const QString &text, bool matchCase, bool wholeWord) {
    QList<SearchResultItem> allResults;
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() || text.trimmed().isEmpty() || m_totalPageNumber <= 0) {
        return allResults;
    }

    Poppler::Page::SearchFlags flags;
    if (!matchCase) {
        flags |= Poppler::Page::IgnoreCase;
    }
    if (wholeWord) {
        flags |= Poppler::Page::WholeWords;
    }

    for (int p = 0; p < m_totalPageNumber; ++p) {
        std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(p));
        if (!pdfPage) continue;

        const QList<QRectF> matches = pdfPage->search(text, flags);
        if (matches.isEmpty()) continue;

        // Extract words on this matched page to construct contextual snippets
        std::vector<std::unique_ptr<Poppler::TextBox>> textBoxList = pdfPage->textList();
        textBoxList.erase(
            std::remove_if(textBoxList.begin(), textBoxList.end(),
                           [](const std::unique_ptr<Poppler::TextBox>& ptr) { return ptr == nullptr; }),
            textBoxList.end()
            );

        std::stable_sort(textBoxList.begin(), textBoxList.end(),
                         [](const std::unique_ptr<Poppler::TextBox>& a, const std::unique_ptr<Poppler::TextBox>& b) {
                             QRectF rectA = a->boundingBox();
                             QRectF rectB = b->boundingBox();
                             qreal overlapTop = std::max(rectA.top(), rectB.top());
                             qreal overlapBottom = std::min(rectA.bottom(), rectB.bottom());
                             qreal overlap = std::max<qreal>(0.0, overlapBottom - overlapTop);
                             qreal minHeight = std::min(rectA.height(), rectB.height());
                             if (minHeight > 0.0 && overlap >= minHeight * 0.5) {
                                 return rectA.left() < rectB.left();
                             }
                             return rectA.top() < rectB.top();
                         });

        for (const QRectF &matchRect : std::as_const(matches)) {
            SearchResultItem item;
            item.pageNum = p + 1; // 1-indexed for display

            QPointF matchCenter = matchRect.center();
            int matchIdx = -1;
            qreal minDistance = 999999.0;

            for (size_t i = 0; i < textBoxList.size(); ++i) {
                if (matchRect.contains(textBoxList[i]->boundingBox().center()) ||
                    textBoxList[i]->boundingBox().intersects(matchRect)) {
                    matchIdx = static_cast<int>(i);
                    break;
                }
                qreal d = QLineF(matchCenter, textBoxList[i]->boundingBox().center()).length();
                if (d < minDistance) {
                    minDistance = d;
                    matchIdx = static_cast<int>(i);
                }
            }

            if (matchIdx >= 0 && matchIdx < static_cast<int>(textBoxList.size())) {
                int startBefore = std::max(0, matchIdx - 4);
                QStringList beforeList;
                for (int b = startBefore; b < matchIdx; ++b) {
                    beforeList.append(textBoxList[b]->text());
                }
                item.textBefore = beforeList.join(" ");

                item.matchText = textBoxList[matchIdx]->text();
                if (item.matchText.isEmpty()) {
                    item.matchText = text;
                }

                int endAfter = std::min(static_cast<int>(textBoxList.size()), matchIdx + 6);
                QStringList afterList;
                for (int a = matchIdx + 1; a < endAfter; ++a) {
                    afterList.append(textBoxList[a]->text());
                }
                item.textAfter = afterList.join(" ");
            } else {
                item.matchText = text;
            }

            allResults.append(item);
        }
    }

    return allResults;
}

QImage PdfDocument::getPageImageData(int pageIndex) {
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() == true || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return QImage();
    }

    std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(pageIndex));
    if (pdfPage == nullptr) {
        return QImage();
    }

    constexpr double renderDpi = 180.0;

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

    textBoxList.erase(
        std::remove_if(textBoxList.begin(), textBoxList.end(),
                       [](const std::unique_ptr<Poppler::TextBox>& ptr) { return ptr == nullptr; }),
        textBoxList.end()
        );

    std::stable_sort(textBoxList.begin(), textBoxList.end(),
                     [](const std::unique_ptr<Poppler::TextBox>& a, const std::unique_ptr<Poppler::TextBox>& b) {
                         QRectF rectA = a->boundingBox();
                         QRectF rectB = b->boundingBox();

                         qreal overlapTop = std::max(rectA.top(), rectB.top());
                         qreal overlapBottom = std::min(rectA.bottom(), rectB.bottom());
                         qreal overlap = std::max<qreal>(0.0, overlapBottom - overlapTop);
                         qreal minHeight = std::min(rectA.height(), rectB.height());

                         if (minHeight > 0.0 && overlap >= minHeight * 0.5) {
                             return rectA.left() < rectB.left();
                         }

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