#include "Libraries/DocumentManager/DocumentManager.h"
#include "Libraries/DocumentManager/PdfDocument.h"

DocumentManager::DocumentManager(QObject* parent)
    : QObject(parent) {

}

DocumentType DocumentManager::GetFileType(const QUrl& qmlFilePath) const {
    QFileInfo qtFilePath(qmlFilePath.toLocalFile());

    if (!qtFilePath.isFile()) {
        return DocumentType::Invalid;
    }
    QString fileExtension = qtFilePath.suffix().toLower();

    if (fileExtension == "pdf") {
        return DocumentType::PDF;
    } else if (fileExtension == "epub") {
        return DocumentType::EPUB;
    } else {
        return DocumentType::Unsupported;
    }
}

void DocumentManager::openDocument(const QUrl& filePath) {
    DocumentType fileType = GetFileType(filePath);
    if (fileType == DocumentType::Invalid) {
        emit errorOccurred("The selected file is missing or unsupported.");
        return;
    }

    if (fileType == DocumentType::Unsupported) {
        emit errorOccurred("This file format is not supported.");
        return;
    }

    if (fileType == DocumentType::PDF) {
        m_activeEngine = std::make_unique<PdfDocument>();
    }

    /* else if (type == DocumentType::EPUB) {
        m_activeEngine = std::make_unique<EpubDocument>();
    } */

    m_activeEngine->getDocumentMetaData(filePath);

    emit activeDocumentChanged();
}

DocumentBase* DocumentManager::activeDocument() const {
    return m_activeEngine.get();
}
