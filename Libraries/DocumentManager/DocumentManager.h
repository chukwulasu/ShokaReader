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
    Q_PROPERTY(DocumentBase* activeDocument READ getActiveDocument NOTIFY activeDocumentChanged)

public:
    explicit DocumentManager(QObject* parent = nullptr);
    ~DocumentManager() override = default;
    Q_INVOKABLE void openDocument(const QUrl& filePath);
    Q_INVOKABLE void releaseDocument();
    Q_INVOKABLE bool unlockPendingDocument(const QString& password);
    Q_INVOKABLE void cancelPendingDocument();
    DocumentBase* getActiveDocument() const;
    DocumentType getFileType(const QUrl& qmlFilePath) const;

signals:
    void activeDocumentChanged();
    void documentLocked(QString fileName);
    void errorOccurred(QString errorMessage);

private:
    std::unique_ptr<DocumentBase> m_activeDocument;
    std::unique_ptr<DocumentBase> m_pendingDocument;
};