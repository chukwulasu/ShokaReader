#pragma once
#include <QAbstractListModel>
#include "Libraries/DocumentManager/DocumentBase.h"

class DocumentPageModel : public QAbstractListModel {
    Q_OBJECT
public:
    explicit DocumentPageModel(DocumentBase *document, QObject *parent = nullptr);
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

private:
    DocumentBase *m_document;
};