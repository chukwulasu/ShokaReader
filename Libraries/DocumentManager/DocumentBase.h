#pragma once

#include <QObject>
#include <QUrl>
#include <QString>
#include <QImage>
#include <QSizeF>
#include <QAbstractListModel>
#include <QVector>
#include <QList>
#include <QMetaType>

enum class DocumentState {
    LoadSuccessful,
    LoadFailed,
    Locked
};

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

struct TextRectItem {
    Q_GADGET

    Q_PROPERTY(QString text MEMBER text CONSTANT)
    Q_PROPERTY(qreal x MEMBER x CONSTANT)
    Q_PROPERTY(qreal y MEMBER y CONSTANT)
    Q_PROPERTY(qreal width MEMBER width CONSTANT)
    Q_PROPERTY(qreal height MEMBER height CONSTANT)

public:
    QString text;
    qreal x = 0.0;
    qreal y = 0.0;
    qreal width = 0.0;
    qreal height = 0.0;

    bool operator==(const TextRectItem& other) const {
        return text == other.text &&
               x == other.x &&
               y == other.y &&
               width == other.width &&
               height == other.height;
    }
};

Q_DECLARE_METATYPE(TextRectItem)

class DocumentBase : public QAbstractListModel{
    Q_OBJECT
    Q_PROPERTY(QUrl fileUrl READ getFileUrl CONSTANT)
    Q_PROPERTY(int totalPageNumber READ getTotalPageNumber CONSTANT)
    Q_PROPERTY(QString title READ getTitle CONSTANT)
    Q_PROPERTY(QVector<TocItem> tableOfContents READ getTableOfContents CONSTANT)

public:
    explicit DocumentBase(QObject* parent = nullptr);
    virtual ~DocumentBase();
    virtual DocumentState getDocumentMetaData(const QUrl &filePath) = 0;
    virtual bool unlock(const QString &password);
    virtual QImage getPageImageData(int pageIndex) = 0;
    virtual const QVector<TocItem>& getTableOfContents();
    Q_INVOKABLE virtual QList<TextRectItem> getPageTextRects(int pageIndex) = 0;
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