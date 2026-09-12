#pragma once

#include <QQuickImageProvider>
#include "Libraries/DocumentManager/DocumentManager.h"

class DocumentImageProvider : public QQuickImageProvider {
public:
    explicit DocumentImageProvider(DocumentManager* docManager);
    ~DocumentImageProvider() override = default;
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    DocumentManager* m_documentManager;
};