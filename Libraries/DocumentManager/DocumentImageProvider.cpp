#include "Libraries/DocumentManager/DocumentImageProvider.h"

DocumentImageProvider::DocumentImageProvider(DocumentManager* docManager)
    : QQuickImageProvider(QQuickImageProvider::Image), m_documentManager(docManager) {

}

QImage DocumentImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    if (!m_documentManager || !m_documentManager->activeDocument()) {
        return QImage();
    }

    QStringList parts = id.split('_');
    if (parts.size() < 2) {
        return QImage();
    }

    int pageNum = parts[1].toInt();
    QSize target = requestedSize.isValid() ? requestedSize : QSize(1024, 1414);

    QImage pageImage = m_documentManager->activeDocument()->renderPageImage(pageNum, target);

    if (size) {
        *size = pageImage.size();
    }

    return pageImage.size().isNull() ? QImage() : pageImage;
}