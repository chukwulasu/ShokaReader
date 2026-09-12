#include "DocumentPageModel.h"
#include "DocumentBase.h"

DocumentPageModel::DocumentPageModel(DocumentBase *document, QObject *parent)
    : QAbstractListModel(parent), m_document(document) {
}

int DocumentPageModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid() || m_document == nullptr) {
        return 0;
    }
    return m_document->GetTotalPageNumber();
}

QVariant DocumentPageModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || m_document == nullptr) {
        return QVariant();
    }

    if (role == Qt::DisplayRole) {
        return index.row();
    }

    return QVariant();
}