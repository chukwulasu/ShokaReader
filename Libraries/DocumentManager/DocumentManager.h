#pragma once

#include <QObject>
#include <QUrl>
#include <QFileInfo>
#include <memory>
#include "Libraries/DocumentManager/DocumentBase.h"

enum class DocumentType {
    PDF,
    EPUB,
    Unsupported,
    Invalid
};

class DocumentManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(DocumentBase* activeDocument READ activeDocument NOTIFY activeDocumentChanged)

public:
    explicit DocumentManager(QObject* parent = nullptr);
    ~DocumentManager() override = default;

    Q_INVOKABLE void openDocument(const QUrl& filePath);
    DocumentBase* activeDocument() const;
    DocumentType GetFileType(const QUrl& qmlFilePath) const;

signals:
    void activeDocumentChanged();
    void errorOccurred(QString errorMessage);

private:
    std::unique_ptr<DocumentBase> m_activeEngine;
};