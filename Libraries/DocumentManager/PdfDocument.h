#pragma once

#include <QObject>
#include "Libraries/DocumentManager/DocumentBase.h"

class PdfDocument :  public QObject, public DocumentBase{
    Q_OBJECT
    Q_PROPERTY(QUrl source READ getSource NOTIFY sourceChanged)

public:
    explicit PdfDocument(QObject* parent = nullptr);
    ~PdfDocument() override = default;
    Q_INVOKABLE void loadDocument(const QUrl& filePath) override;
    QUrl getSource() const;

signals:
    void sourceChanged();

private:
    QUrl m_sourceUrl;
};
