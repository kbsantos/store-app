enum StaffRole { staff, editor, manager, owner }

enum CatalogPermission { editCatalog, deleteCatalog, restoreBackup, clearAudit, exportSyncPackage, importSyncPackage }

class StaffAccessPolicy {
  static bool can(StaffRole role, CatalogPermission permission) {
    switch (permission) {
      case CatalogPermission.editCatalog:
      case CatalogPermission.deleteCatalog:
        return role == StaffRole.editor || role == StaffRole.manager || role == StaffRole.owner;
      case CatalogPermission.restoreBackup:
      case CatalogPermission.clearAudit:
      case CatalogPermission.exportSyncPackage:
      case CatalogPermission.importSyncPackage:
        return role == StaffRole.manager || role == StaffRole.owner;
    }
  }
}
