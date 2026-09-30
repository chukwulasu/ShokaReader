#include "Libraries/DocumentManager/DocumentPageImageProvider.h"

DocumentPageImageProvider::DocumentPageImageProvider(DocumentManager* docManager)
    : QQuickImageProvider(QQuickImageProvider::Image), m_documentManager(docManager) {

}

DocumentPageImageProvider::~DocumentPageImageProvider() = default;

QImage DocumentPageImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    if (m_documentManager == nullptr || m_documentManager->getActiveDocument() == nullptr) {
        return QImage();
    }

    QStringList parts = id.split('_');
    if (parts.size() < 2) {
        return QImage();
    }

    int pageNum = parts[1].toInt();
    QImage pageImage = m_documentManager->getActiveDocument()->getPageImageData(pageNum);

    if (size != nullptr) {
        *size = pageImage.size();
    }

    return pageImage.size().isNull() ? QImage() : pageImage;
}