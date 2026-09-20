#pragma once

#include <QObject>
#include <QUrl>
#include <QString>
#include <QImage>
#include <QSizeF>
#include <QAbstractListModel>
#include <QVector>
#include <QVariantList>
#include <QVariantMap>

class DocumentBase : public QAbstractListModel{
    Q_OBJECT
    Q_PROPERTY(QUrl fileUrl READ getFileUrl CONSTANT)
    Q_PROPERTY(int totalPageNumber READ GetTotalPageNumber CONSTANT)
    Q_PROPERTY(QString title READ GetTitle CONSTANT)
    Q_PROPERTY(QVariantList tableOfContents READ getTableOfContents NOTIFY tableOfContentsChanged)

public:
    explicit DocumentBase(QObject* parent = nullptr);
    virtual ~DocumentBase();
    virtual void getDocumentMetaData(const QUrl &filePath) = 0;
    virtual QImage renderPageImage(int pageIndex, const QSize& targetSize) = 0;
    virtual QVariantList getTableOfContents() = 0;
    QUrl getFileUrl() const;
    int GetTotalPageNumber() const;
    QString GetTitle() const;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

public:
    struct TocItem {
        QString title;
        int pageNum = -1;
        bool hasChildren = false;
        QVector<TocItem> children;
    };

signals:
    void tableOfContentsChanged();

protected:
    QVariantMap toVariantMap(const TocItem& item) const;

protected:
    QUrl m_fileUrl;
    int m_totalPageNumber = 0;
    QString m_title = "";
};
