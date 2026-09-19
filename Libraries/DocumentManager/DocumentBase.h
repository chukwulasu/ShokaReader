#pragma once

#include <QObject>
#include <QUrl>
#include <QString>
#include <QImage>
#include <QSizeF>
#include <QAbstractListModel>

class DocumentBase : public QAbstractListModel{
    Q_OBJECT
    Q_PROPERTY(QUrl source READ getSource CONSTANT)
    Q_PROPERTY(int totalPageNumber READ GetTotalPageNumber CONSTANT)
    Q_PROPERTY(QString title READ GetTitle CONSTANT)

public:
    explicit DocumentBase(QObject* parent = nullptr);
    virtual ~DocumentBase();
    virtual void getDocumentMetaData(const QUrl &filePath) = 0;
    virtual QImage renderPageImage(int pageIndex, const QSize& targetSize) = 0;
    QUrl getSource() const;
    int GetTotalPageNumber() const;
    QString GetTitle() const;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

protected:
    QUrl m_fileUrl;
    int m_totalPageNumber = 0;
    QString m_title = "";
};
