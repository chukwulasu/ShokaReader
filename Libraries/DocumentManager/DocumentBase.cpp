#include "Libraries/DocumentManager/DocumentBase.h"

DocumentBase::DocumentBase(){

}

size_t DocumentBase::TotalPageNumber(){
    return static_cast<size_t>(m_totalPageNumber);
}

size_t DocumentBase::GetCurrentPageNumber(){
    return static_cast<size_t>(m_currentPageNumber);
}
