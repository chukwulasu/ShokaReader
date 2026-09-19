#include "Libraries/DocumentManager/DocumentBase.h"

DocumentBase::DocumentBase(QObject* parent)
    : QAbstractListModel(parent){

}

DocumentBase::~DocumentBase() = default;

int DocumentBase::GetTotalPageNumber() const{
    return m_totalPageNumber;
}

QString DocumentBase::GetTitle() const{
    return m_title;
}

QUrl DocumentBase::getSource() const{
    return m_fileUrl;
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