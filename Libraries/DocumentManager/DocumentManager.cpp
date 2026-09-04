#include "Libraries/DocumentManager/DocumentManager.h"
#include "Libraries/DocumentManager/PdfDocument.h"

DocumentManager::DocumentManager(QObject* parent)
    : QObject(parent)
{
}

DocumentType DocumentManager::GetFileType(const QUrl& qmlFilePath) const{

    QFileInfo qtFilePath (qmlFilePath.toLocalFile());

    if(!qtFilePath.isFile()){
        return DocumentType::Invalid;
    }
    QString fileExtension = qtFilePath.suffix().toLower();

    if(fileExtension == "pdf"){
        return DocumentType::PDF;
    }

    else if(fileExtension == "epub"){
        return DocumentType::EPUB;
    }

    else{
        return DocumentType::Unsupported;
    }
}

void DocumentManager::openDocument(const QUrl filePath){
    DocumentType fileType = GetFileType(filePath);
    if (fileType == DocumentType::Invalid) {
        emit errorOccurred("The selected file is missing or Unsupported.");
        return;
    }

    if (fileType == DocumentType::Unsupported) {
        emit errorOccurred("This ebook format is not supported yet.");
        return;
    }

    if (fileType == DocumentType::PDF) {
        // Automatically deletes previous engine from memory and creates a PdfDocument child object
        m_activeEngine = std::make_unique<PdfDocument>();
    }

    /* else if (type == DocumentType::EPUB) {
        m_activeEngine = std::make_unique<EpubDocument>();
    } */

    if (m_activeEngine != nullptr) {
        m_activeEngine->loadDocument(filePath);

        // Update states and trigger UI bindings
        m_fileUrl = filePath;
        m_currentType = fileType;
        emit fileUrlChanged();
        emit typeChanged();
    }
}

QUrl DocumentManager::fileUrl() const {
    return m_fileUrl;
}

DocumentType DocumentManager::currentType() const {
    return m_currentType;
}