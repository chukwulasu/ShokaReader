#include "Libraries/DocumentManager/DocumentBase.h"

DocumentBase::DocumentBase(QObject* parent)
    : QAbstractListModel(parent) {
}

DocumentBase::~DocumentBase() = default;

bool DocumentBase::unlock(const QString &userPassword, const QString &ownerPassword) {
    Q_UNUSED(userPassword);
    Q_UNUSED(ownerPassword);
    return false;
}

bool DocumentBase::canCopy() const {
    return m_canCopy;
}

QList<QRectF> DocumentBase::searchPage(int pageIndex, const QString &text, bool matchCase, bool wholeWord) {
    Q_UNUSED(pageIndex);
    Q_UNUSED(text);
    Q_UNUSED(matchCase);
    Q_UNUSED(wholeWord);
    return {};
}

QList<SearchResultItem> DocumentBase::searchDocument(const QString &text, bool matchCase, bool wholeWord) {
    Q_UNUSED(text);
    Q_UNUSED(matchCase);
    Q_UNUSED(wholeWord);
    return {};
}

void DocumentBase::startSearch(const QString &text, bool matchCase, bool wholeWord) {
    Q_UNUSED(text);
    Q_UNUSED(matchCase);
    Q_UNUSED(wholeWord);
    emit searchResultsReady(text, {});
}

void DocumentBase::cancelSearch() {
}

int DocumentBase::resolvePage(int pageNum, const QString &targetLocation) const {
    Q_UNUSED(targetLocation);
    return pageNum > 0 ? pageNum : 1;
}

int DocumentBase::resolvePage(const QVariantMap &item) const {
    int page = item.value("pageNum").toInt();
    QString target = item.value("targetLocation").toString();
    return resolvePage(page, target);
}

const QVector<TocItem>& DocumentBase::getTableOfContents() {
    return m_tableOfContents;
}

QUrl DocumentBase::getFileUrl() const {
    return m_fileUrl;
}

int DocumentBase::getTotalPageNumber() const {
    return m_totalPageNumber;
}

QString DocumentBase::getTitle() const {
    return m_title;
}

int DocumentBase::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) {
        return 0;
    }
    return m_totalPageNumber;
}

QVariant DocumentBase::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_totalPageNumber) {
        return QVariant();
    }

    if (role == Qt::DisplayRole) {
        return index.row();
    }

    return QVariant();
}