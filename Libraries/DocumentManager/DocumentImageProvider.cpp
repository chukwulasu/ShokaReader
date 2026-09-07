#include "Libraries/DocumentManager/DocumentImageProvider.h"

DocumentImageProvider::DocumentImageProvider(DocumentManager* docManager)
    : QQuickImageProvider(QQuickImageProvider::Image), m_docManager(docManager) {

}

QImage DocumentImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    if (!m_docManager || !m_docManager->activeDocument()) {
        return QImage();
    }

    // Expected format from QML: "page_0", "page_1", etc.
    QStringList parts = id.split('_');
    if (parts.size() < 2) {
        return QImage();
    }

    int pageNum = parts[1].toInt();
    QSize target = requestedSize.isValid() ? requestedSize : QSize(1024, 1414);

    // Call down to the active polymorphic document engine
    QImage img = m_docManager->activeDocument()->renderPageImage(pageNum, target);

    if (size) {
        *size = img.size();
    }

    return img.size().isNull() ? QImage() : img;
}