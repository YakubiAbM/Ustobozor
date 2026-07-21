import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/project_model.dart';

class ProjectStorageService {
  ProjectStorageService._();

  static final ProjectStorageService instance = ProjectStorageService._();

  static const String boxName = 'projectsBox';
  static const int maxProjects = 100;
  static const int maxImagesPerProject = 5;

  Box<dynamic>? _box;

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(boxName);
  }

  Future<List<ProjectModel>> getAllProjects() async {
    await init();
    final projects =
        _box!.values.whereType<Map>().map(ProjectModel.fromMap).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return projects;
  }

  Future<ProjectModel?> getProjectById(String id) async {
    await init();
    final raw = _box!.get(id);
    if (raw is! Map) return null;
    return ProjectModel.fromMap(raw);
  }

  Future<ProjectModel> addProject(ProjectModel project) async {
    await init();
    if (_box!.length >= maxProjects && !_box!.containsKey(project.id)) {
      throw StateError('Можно сохранить максимум $maxProjects проектов.');
    }

    final prepared = await _prepareProject(project);
    await _box!.put(prepared.id, prepared.toMap());
    return prepared;
  }

  Future<ProjectModel> updateProject(ProjectModel project) async {
    await init();
    final existing = await getProjectById(project.id);
    final prepared = await _prepareProject(project, existingProject: existing);
    await _box!.put(prepared.id, prepared.toMap());
    return prepared;
  }

  Future<void> deleteProject(String id) async {
    await init();
    final existing = await getProjectById(id);
    if (existing != null) {
      for (final imagePath in existing.images) {
        await _safeDeleteFile(imagePath);
      }
      await _safeDeleteFile(existing.beforeVideo);
      await _safeDeleteFile(existing.afterVideo);

      final directory = await _projectImagesDirectory(id);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }

    await _box!.delete(id);
  }

  Future<ProjectModel> _prepareProject(
    ProjectModel project, {
    ProjectModel? existingProject,
  }) async {
    final persistedBeforeImages = await _persistImages(
      project.id,
      project.beforeImages.take(maxImagesPerProject).toList(),
      oldImages: existingProject?.beforeImages ?? const [],
      groupPrefix: 'before',
    );
    final persistedAfterImages = await _persistImages(
      project.id,
      project.afterImages.take(maxImagesPerProject).toList(),
      oldImages: existingProject?.afterImages ?? const [],
      groupPrefix: 'after',
    );
    final persistedBeforeVideo = await _persistSingleMedia(
      project.id,
      project.beforeVideo,
      oldPath: existingProject?.beforeVideo,
      filePrefix: 'before_video',
    );
    final persistedAfterVideo = await _persistSingleMedia(
      project.id,
      project.afterVideo,
      oldPath: existingProject?.afterVideo,
      filePrefix: 'after_video',
    );

    return project.copyWith(
      title: project.title.trim(),
      client: project.client.trim(),
      phone: project.phone.trim(),
      note: project.note.trim(),
      beforeImages: persistedBeforeImages,
      afterImages: persistedAfterImages,
      beforeVideo: persistedBeforeVideo,
      afterVideo: persistedAfterVideo,
    );
  }

  Future<List<String>> _persistImages(
    String projectId,
    List<String> sourcePaths, {
    required List<String> oldImages,
    required String groupPrefix,
  }) async {
    final directory = await _projectImagesDirectory(projectId);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final normalizedDirectory = _normalizePath(directory.path);
    final result = <String>[];

    for (final rawPath in sourcePaths) {
      final sourcePath = rawPath.trim();
      if (sourcePath.isEmpty) continue;

      final normalizedSource = _normalizePath(sourcePath);
      if (normalizedSource.startsWith(normalizedDirectory)) {
        result.add(sourcePath);
        continue;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) continue;

      final extension = _fileExtension(sourcePath);
      final fileName =
          '${groupPrefix}_${DateTime.now().microsecondsSinceEpoch}_${result.length}$extension';
      final destination = File(
        '${directory.path}${Platform.pathSeparator}$fileName',
      );
      await sourceFile.copy(destination.path);
      result.add(destination.path);
    }

    for (final oldImage in oldImages) {
      if (!result.contains(oldImage)) {
        await _safeDeleteFile(oldImage);
      }
    }

    return result;
  }

  Future<String?> _persistSingleMedia(
    String projectId,
    String? sourcePath, {
    required String? oldPath,
    required String filePrefix,
  }) async {
    final normalizedSource = sourcePath?.trim() ?? '';
    if (normalizedSource.isEmpty) {
      if (oldPath != null && oldPath.isNotEmpty) {
        await _safeDeleteFile(oldPath);
      }
      return null;
    }

    final directory = await _projectImagesDirectory(projectId);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final normalizedDirectory = _normalizePath(directory.path);
    if (_normalizePath(normalizedSource).startsWith(normalizedDirectory)) {
      if (oldPath != null && oldPath != normalizedSource) {
        await _safeDeleteFile(oldPath);
      }
      return normalizedSource;
    }

    final sourceFile = File(normalizedSource);
    if (!await sourceFile.exists()) return oldPath;

    final extension = _fileExtension(normalizedSource);
    final destination = File(
      '${directory.path}${Platform.pathSeparator}${filePrefix}_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await sourceFile.copy(destination.path);

    if (oldPath != null && oldPath.isNotEmpty && oldPath != destination.path) {
      await _safeDeleteFile(oldPath);
    }
    return destination.path;
  }

  Future<Directory> _projectImagesDirectory(String projectId) async {
    final appDirectory = await getApplicationDocumentsDirectory();
    return Directory(
      '${appDirectory.path}${Platform.pathSeparator}project_images${Platform.pathSeparator}$projectId',
    );
  }

  Future<void> _safeDeleteFile(String? path) async {
    try {
      if (path == null || path.trim().isEmpty) return;
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String _normalizePath(String path) => path.replaceAll('\\', '/');

  String _fileExtension(String path) {
    final fileName = path.split(RegExp(r'[\\/]')).last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return '.jpg';
    return fileName.substring(dotIndex);
  }
}
