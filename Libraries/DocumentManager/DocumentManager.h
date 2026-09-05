#pragma once

#include <QObject>
#include <QUrl>
#include <QFileInfo>
#include <memory>
#include "Libraries/DocumentManager/DocumentBase.h"

enum class DocumentType{
    PDF,
    EPUB,
    Unsupported,
    Invalid
};

class DocumentManager : public QObject{
    Q_OBJECT
    Q_PROPERTY(QUrl getFileUrl READ getFileUrl NOTIFY fileUrlChanged)
    Q_PROPERTY(DocumentType currentType READ currentType NOTIFY typeChanged)

public:
explicit DocumentManager(QObject*parent = nullptr);
~DocumentManager() override = default;

Q_INVOKABLE void openDocument(const QUrl filePath);
QUrl getFileUrl() const;
DocumentType currentType() const;
DocumentType GetFileType(const QUrl& qmlFilePath) const;

signals:
void fileUrlChanged();
void typeChanged(); // TODO: remove if later unused after EPUB features are added
void errorOccurred(QString errorMessage);

private:
QUrl m_fileUrl;
DocumentType m_currentType = DocumentType::Invalid; //TODO: remove later if unused after EPUB features are added
std::unique_ptr<DocumentBase> m_activeEngine;

};


