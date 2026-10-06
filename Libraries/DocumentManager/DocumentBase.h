#pragma once

#include <QObject>
#include <QUrl>
#include <QString>
#include <QImage>
#include <QSizeF>
#include <QRectF>
#include <QAbstractListModel>
#include <QVector>
#include <QList>
#include <QVariantMap>
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
    Q_PROPERTY(QString targetLocation MEMBER targetLocation CONSTANT)

public:
    QString title;
    int pageNum = -1;
    bool hasChildren = false;
    QVector<TocItem> TocItemChildren;
    QString targetLocation;

    bool operator==(const TocItem& other) const {
        return title == other.title &&
               pageNum == other.pageNum &&
               hasChildren == other.hasChildren &&
               TocItemChildren == other.TocItemChildren &&
               targetLocation == other.targetLocation;
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

struct SearchResultItem {
    Q_GADGET

    Q_PROPERTY(int pageNum MEMBER pageNum CONSTANT)
    Q_PROPERTY(QString textBefore MEMBER textBefore CONSTANT)
    Q_PROPERTY(QString matchText MEMBER matchText CONSTANT)
    Q_PROPERTY(QString textAfter MEMBER textAfter CONSTANT)

public:
    int pageNum = 1;
    QString textBefore;
    QString matchText;
    QString textAfter;

    bool operator==(const SearchResultItem& other) const {
        return pageNum == other.pageNum &&
               textBefore == other.textBefore &&
               matchText == other.matchText &&
               textAfter == other.textAfter;
    }
};

Q_DECLARE_METATYPE(SearchResultItem)

class DocumentBase : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QUrl fileUrl READ getFileUrl CONSTANT)
    Q_PROPERTY(int totalPageNumber READ getTotalPageNumber CONSTANT)
    Q_PROPERTY(QString title READ getTitle CONSTANT)
    Q_PROPERTY(QVector<TocItem> tableOfContents READ getTableOfContents CONSTANT)
    Q_PROPERTY(bool canCopy READ canCopy CONSTANT)

public:
    explicit DocumentBase(QObject* parent = nullptr);
    virtual ~DocumentBase();
    virtual DocumentState getDocumentMetaData(const QUrl &filePath) = 0;
    virtual bool unlock(const QString &userPassword, const QString &ownerPassword = QString());
    virtual QImage getPageImageData(int pageIndex) = 0;
    virtual const QVector<TocItem>& getTableOfContents();
    Q_INVOKABLE virtual QList<TextRectItem> getPageTextRects(int pageIndex) = 0;
    Q_INVOKABLE virtual QSizeF getPageSizePoints(int pageIndex) = 0;
    Q_INVOKABLE virtual QList<QRectF> searchPage(int pageIndex, const QString &text, bool matchCase = false, bool wholeWord = false);
    Q_INVOKABLE virtual QList<SearchResultItem> searchDocument(const QString &text, bool matchCase = false, bool wholeWord = false);

    // Asynchronous Background Search API
    Q_INVOKABLE virtual void startSearch(const QString &text, bool matchCase = false, bool wholeWord = false);
    Q_INVOKABLE virtual void cancelSearch();

    // Polymorphic Navigation (supports both JS Object map and direct ints/strings)
    Q_INVOKABLE virtual int resolvePage(int pageNum, const QString &targetLocation = QString()) const;
    Q_INVOKABLE virtual int resolvePage(const QVariantMap &item) const;

    QUrl getFileUrl() const;
    int getTotalPageNumber() const;
    QString getTitle() const;
    bool canCopy() const;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

signals:
    void searchResultsReady(const QString &query, const QList<SearchResultItem> &results);

protected:
    QUrl m_fileUrl;
    int m_totalPageNumber = 0;
    QString m_title = "";
    QVector<TocItem> m_tableOfContents;
    bool m_canCopy = true;
};