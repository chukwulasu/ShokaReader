#pragma once

#include <QObject>
#include <QUrl>
#include <QString>
#include <QImage>
#include <QSizeF>
#include <QAbstractListModel>
#include <QVector>
#include <QVariantList>
#include <QMetaType>

struct TocItem {
    Q_GADGET

    Q_PROPERTY(QString title MEMBER title CONSTANT)
    Q_PROPERTY(int pageNum MEMBER pageNum CONSTANT)
    Q_PROPERTY(bool hasChildren MEMBER hasChildren CONSTANT)
    Q_PROPERTY(QVector<TocItem> TocItemChildren MEMBER TocItemChildren CONSTANT)

public:
    QString title;
    int pageNum = -1;
    bool hasChildren = false;
    QVector<TocItem> TocItemChildren;
    bool operator==(const TocItem& other) const {
        return title == other.title &&
               pageNum == other.pageNum &&
               hasChildren == other.hasChildren &&
               TocItemChildren == other.TocItemChildren;
    }
};

Q_DECLARE_METATYPE(TocItem)

class DocumentBase : public QAbstractListModel{
    Q_OBJECT
    Q_PROPERTY(QUrl fileUrl READ getFileUrl CONSTANT)
    Q_PROPERTY(int totalPageNumber READ getTotalPageNumber CONSTANT)
    Q_PROPERTY(QString title READ getTitle CONSTANT)
    Q_PROPERTY(QVector<TocItem> tableOfContents READ getTableOfContents CONSTANT)

public:
    explicit DocumentBase(QObject* parent = nullptr);
    virtual ~DocumentBase();
    virtual bool getDocumentMetaData(const QUrl &filePath) = 0;
    virtual QImage getPageImageData(int pageIndex) = 0;
    const QVector<TocItem>& getTableOfContents() const;
    Q_INVOKABLE virtual QVariantList getPageTextRects(int pageIndex) = 0;
    Q_INVOKABLE virtual QSizeF getPageSizePoints(int pageIndex) = 0;
    QUrl getFileUrl() const;
    int getTotalPageNumber() const;
    QString getTitle() const;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

protected:
    QUrl m_fileUrl;
    int m_totalPageNumber = 0;
    QString m_title = "";
    QVector<TocItem> m_tableOfContents;
};
