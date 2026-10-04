#include "Libraries/DocumentManager/DocumentBase.h"

DocumentBase::DocumentBase(QObject* parent)
    : QAbstractListModel(parent){

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

const QVector<TocItem>& DocumentBase::getTableOfContents(){
    return m_tableOfContents;
}

QUrl DocumentBase::getFileUrl() const{
    return m_fileUrl;
}

int DocumentBase::getTotalPageNumber() const{
    return m_totalPageNumber;
}

QString DocumentBase::getTitle() const{
    return m_title;
}

int DocumentBase::rowCount(const QModelIndex &parent) const {
    if (parent.isValid() == true) {
        return 0;
    }
    return m_totalPageNumber;
}

QVariant DocumentBase::data(const QModelIndex &index, int role) const {
    if (index.isValid() == false || index.row() < 0 || index.row() >= m_totalPageNumber) {
        return QVariant();
    }

    if (role == Qt::DisplayRole) {
        return index.row();
    }

    return QVariant();
}