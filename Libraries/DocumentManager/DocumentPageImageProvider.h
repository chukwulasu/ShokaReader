#pragma once

#include <QQuickImageProvider>
#include "Libraries/DocumentManager/DocumentManager.h"

class DocumentPageImageProvider : public QQuickImageProvider {
public:
    explicit DocumentPageImageProvider(DocumentManager* docManager);
    ~DocumentPageImageProvider() override = default;
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    DocumentManager* m_documentManager;
};