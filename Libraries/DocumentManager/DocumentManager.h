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
    Q_PROPERTY(DocumentType currentType READ currentType NOTIFY typeChanged)

public:
    explicit DocumentManager(QObject* parent = nullptr);
    ~DocumentManager() override = default;

    Q_INVOKABLE void openDocument(const QUrl& filePath);
    DocumentBase* activeDocument() const;
    DocumentType currentType() const;
    DocumentType GetFileType(const QUrl& qmlFilePath) const;

signals:
    void activeDocumentChanged();
    void typeChanged();
    void errorOccurred(QString errorMessage);

private:
    DocumentType m_currentType = DocumentType::Invalid;
    std::unique_ptr<DocumentBase> m_activeEngine;
};