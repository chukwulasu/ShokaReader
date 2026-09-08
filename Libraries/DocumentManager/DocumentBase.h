#pragma once

#include <QObject>
#include <QUrl>
#include <Qstring>
#include <QImage>
#include <QSizeF>

class DocumentBase : public QObject{
    Q_OBJECT
    Q_PROPERTY(QUrl source READ getSource CONSTANT)
    Q_PROPERTY(int totalPageNumber READ GetTotalPageNumber CONSTANT)
    /*Q_PROPERTY(int currentPageNumber READ GetCurrentPageNumber CONSTANT)
    TODO: either remove it since it's not currently used or change it from CONSTANT to PROPERTY */
    Q_PROPERTY(QString title READ GetTitle CONSTANT)
public:
    explicit DocumentBase(QObject* parent = nullptr);
    virtual ~DocumentBase();
    virtual void getDocumentMetaData(const QUrl &filePath) = 0;
    Q_INVOKABLE virtual QImage renderPageImage(int pageIndex, const QSize& targetSize) = 0;
    Q_INVOKABLE virtual QSizeF nativePageSize(int pageIndex) const = 0;
    QUrl getSource() const;
    int GetTotalPageNumber() const;
    //int GetCurrentPageNumber() const;
    QString GetTitle() const;

protected:
    QUrl m_sourceUrl;
    int m_totalPageNumber = 0;
    int m_currentPageNumber = 1;
    QString m_title = "";
};
