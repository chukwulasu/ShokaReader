#include "Libraries/DocumentManager/DocumentManager.h"
#include "Libraries/DocumentManager/PdfDocument.h"

DocumentManager::DocumentManager(QObject* parent)
    : QObject(parent) {

}

DocumentType DocumentManager::getFileType(const QUrl& qmlFilePath) const {
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
    DocumentType fileType = getFileType(filePath);
    if (fileType == DocumentType::Invalid) {
        const QString errorMessage = QFileInfo(filePath.toLocalFile()).completeBaseName() +
            "is missing or an invalid file";
        emit errorOccurred(errorMessage);
        return;
    }

    if (fileType == DocumentType::Unsupported) {
        emit errorOccurred("This file format is not supported.");
        return;
    }

    if (fileType == DocumentType::PDF) {
       m_activeDocument = std::make_unique<PdfDocument>();
    }

    /* else if (type == DocumentType::EPUB) {
       m_activeDocument = std::make_unique<EpubDocument>();
    } */

   if(m_activeDocument->getDocumentMetaData(filePath) == true){
        emit activeDocumentChanged();
   }else{
       const QString errorMessage = "Failed to open " + QFileInfo(filePath.toLocalFile()).completeBaseName();
       emit errorOccurred(errorMessage);
   }
}

void DocumentManager::releaseDocument(){
    if(m_activeDocument != nullptr){
        m_activeDocument = nullptr;
    }
}

DocumentBase* DocumentManager::getActiveDocument() const {
    return m_activeDocument.get();
}
