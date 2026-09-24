/* The frozen document. See zuh_document.h. */
#include <stdlib.h>

#include "zuh_document.h"

zuh_doc *
zuh_doc_new(void) {
  return (zuh_doc *) calloc(1, sizeof(zuh_doc));
}

void
zuh_doc_free(zuh_doc *doc) {
  if (doc == NULL)
    return;
  free(doc->problems);
  free(doc);
}
