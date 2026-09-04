#include <QFileInfo>
#include <QUrl>
#include "Libraries/DocumentManager/PdfDocument.h"
#include "Libraries/DocumentManager/DocumentManager.h"

PdfDocument::PdfDocument(QObject* parent)
    : QObject(parent), DocumentBase(){

}

void PdfDocument::loadDocument(const QUrl& filePath) {
    m_sourceUrl = filePath;
    // TODO: more implementatins might be made here

    emit sourceChanged();
}

QUrl PdfDocument::getSource() const {
    return m_sourceUrl;
}