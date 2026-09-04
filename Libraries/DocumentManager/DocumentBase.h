#pragma once

#include <QUrl>
#include <Qstring> //TODO: may need to remove depnding on file type of m_title

class DocumentBase{
public:
    DocumentBase();
    virtual ~DocumentBase() = default;
    virtual void loadDocument(const QUrl &filePath) = 0;
    size_t TotalPageNumber();
    size_t GetCurrentPageNumber();

protected:
    uint32_t m_totalPageNumber = 0;
    uint32_t m_currentPageNumber = 0;
    QString m_title; //TODO: may need to change to another qt class
};
