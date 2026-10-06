#include "Libraries/DocumentManager/PdfDocument.h"

#include <QFileInfo>
#include <QDebug>
#include <QLineF>
#include <QThreadPool>
#include <QMutexLocker>
#include <QStringMatcher>
#include <algorithm>

PdfDocument::PdfDocument(QObject* parent)
    : DocumentBase(parent) {}

PdfDocument::~PdfDocument() {
    cancelSearch();
}

DocumentState PdfDocument::getDocumentMetaData(const QUrl& filePath) {
    cancelSearch();
    m_fileUrl = filePath;
    QString localPath = filePath.toLocalFile();

    {
        QMutexLocker locker(&m_docMutex);
        m_pdfDocument = Poppler::Document::load(localPath);
    }

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

    {
        QMutexLocker cacheLocker(&m_cacheMutex);
        m_pageTextCache.fill(QString(), m_totalPageNumber);
    }

    updatePermissions();
    return DocumentState::LoadSuccessful;
}

bool PdfDocument::unlock(const QString& userPassword, const QString& ownerPassword) {
    QMutexLocker locker(&m_docMutex);
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

        {
            QMutexLocker cacheLocker(&m_cacheMutex);
            m_pageTextCache.fill(QString(), m_totalPageNumber);
        }

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

QImage PdfDocument::getPageImageData(int pageIndex) {
    QMutexLocker locker(&m_docMutex);
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
    QMutexLocker locker(&m_docMutex);
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
                     });

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
    QMutexLocker locker(&m_docMutex);
    if (m_pdfDocument == nullptr || m_pdfDocument->isLocked() == true || pageIndex < 0 || pageIndex >= m_totalPageNumber) {
        return QSizeF(0, 0);
    }
    std::unique_ptr<Poppler::Page> pdfPage(m_pdfDocument->page(pageIndex));
    if (pdfPage == nullptr) {
        return QSizeF(0, 0);
    }
    return pdfPage->pageSizeF();
}

QList<QRectF> PdfDocument::searchPage(int pageIndex, const QString &text, bool matchCase, bool wholeWord) {
    QMutexLocker locker(&m_docMutex);
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

// Synchronous fallback (delegates to startSearch logic)
QList<SearchResultItem> PdfDocument::searchDocument(const QString &text, bool matchCase, bool wholeWord) {
    Q_UNUSED(text);
    Q_UNUSED(matchCase);
    Q_UNUSED(wholeWord);
    return {};
}

void PdfDocument::cancelSearch() {
    m_activeSearchId.fetch_add(1);
}

void PdfDocument::startSearch(const QString &text, bool matchCase, bool wholeWord) {
    const uint64_t currentId = ++m_activeSearchId;
    const QString query = text.trimmed();

    if (query.isEmpty() || m_totalPageNumber <= 0) {
        emit searchResultsReady(text, {});
        return;
    }

    QThreadPool::globalInstance()->start([this, text, query, matchCase, wholeWord, currentId]() {
        QStringMatcher matcher(query, matchCase ? Qt::CaseSensitive : Qt::CaseInsensitive);
        QList<SearchResultItem> results;

        for (int p = 0; p < m_totalPageNumber; ++p) {
            if (m_activeSearchId.load() != currentId) {
                return; // Aborted by newer search query
            }

            QString pageText;
            {
                QMutexLocker cacheLocker(&m_cacheMutex);
                if (p < m_pageTextCache.size()) {
                    pageText = m_pageTextCache[p];
                }
            }

            // Extract plain text on demand if not yet cached
            if (pageText.isEmpty()) {
                {
                    QMutexLocker docLocker(&m_docMutex);
                    if (m_pdfDocument && !m_pdfDocument->isLocked() && p < m_totalPageNumber) {
                        std::unique_ptr<Poppler::Page> page(m_pdfDocument->page(p));
                        if (page) {
                            pageText = page->text(QRectF());
                        }
                    }
                }
                {
                    QMutexLocker cacheLocker(&m_cacheMutex);
                    if (p < m_pageTextCache.size()) {
                        m_pageTextCache[p] = pageText;
                    }
                }
            }

            if (pageText.isEmpty()) continue;

            // Boyer-Moore linear search across this page's plain text
            qsizetype from = 0;
            while (from < pageText.length()) {
                if (m_activeSearchId.load() != currentId) return;

                qsizetype matchIdx = matcher.indexIn(pageText, from);
                if (matchIdx == -1) break;

                bool valid = true;
                if (wholeWord) {
                    if (matchIdx > 0 && pageText.at(matchIdx - 1).isLetterOrNumber()) {
                        valid = false;
                    }
                    qsizetype endIdx = matchIdx + query.length();
                    if (endIdx < pageText.length() && pageText.at(endIdx).isLetterOrNumber()) {
                        valid = false;
                    }
                }

                if (valid) {
                    SearchResultItem item;
                    item.pageNum = p + 1; // 1-indexed for display

                    int startBefore = std::max<int>(0, static_cast<int>(matchIdx) - 35);
                    int endAfter = std::min<int>(static_cast<int>(pageText.length()), static_cast<int>(matchIdx + query.length()) + 45);

                    QString before = pageText.mid(startBefore, matchIdx - startBefore);
                    before.replace(QLatin1Char('\n'), QLatin1Char(' '));
                    before.replace(QLatin1Char('\r'), QLatin1Char(' '));
                    item.textBefore = before.trimmed();

                    item.matchText = pageText.mid(matchIdx, query.length());

                    QString after = pageText.mid(matchIdx + query.length(), endAfter - (matchIdx + query.length()));
                    after.replace(QLatin1Char('\n'), QLatin1Char(' '));
                    after.replace(QLatin1Char('\r'), QLatin1Char(' '));
                    item.textAfter = after.trimmed();

                    results.append(std::move(item));
                }

                from = matchIdx + std::max<qsizetype>(1, query.length());
            }
        }

        // Deliver results back to the GUI thread
        if (m_activeSearchId.load() == currentId) {
            QMetaObject::invokeMethod(this, [this, text, results]() {
                emit searchResultsReady(text, results);
            }, Qt::QueuedConnection);
        }
    });
}

const QVector<TocItem>& PdfDocument::getTableOfContents() {
    QMutexLocker locker(&m_docMutex);
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