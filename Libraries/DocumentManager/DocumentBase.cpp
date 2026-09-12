#include "Libraries/DocumentManager/DocumentBase.h"
#include "DocumentPageModel.h"

DocumentBase::DocumentBase(QObject* parent)
    : QObject(parent){
    m_pageModel = new DocumentPageModel(this, this);
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

QAbstractListModel* DocumentBase::getPageModel() const {
    return m_pageModel;
}