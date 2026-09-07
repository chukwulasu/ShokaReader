#include "Libraries/DocumentManager/DocumentBase.h"

DocumentBase::DocumentBase(QObject* parent)
    : QObject(parent){

}
DocumentBase::~DocumentBase() = default;

int DocumentBase::GetTotalPageNumber() const{
    return m_totalPageNumber;
}

int DocumentBase::GetCurrentPageNumber() const{
    return m_currentPageNumber;
}

QString DocumentBase::GetTitle() const{
    return m_title;
}

QUrl DocumentBase::getSource() const{
    return m_sourceUrl;
}
