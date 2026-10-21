import Foundation
import taskchampShared
import UIKit

extension EditTaskView {
    var didChange: Bool {
        let timeForSave: Date? = didSetTime
            ? time
            : (didSetDate ? UserDefaultsManager.standard.defaultDueTime() : nil)
        return task.project ?? "" != project ||
            task.description != description ||
            task.status != status ||
            task.priority != (priority == TCTask.Priority.none ? nil : priority) ||
            task.due != Calendar.current.mergeDateWithTime(
                date: didSetDate ? due : nil,
                time: timeForSave
            ) ||
            task.tags ?? [] != tags
    }

    func calculateNextField() {
        focusedField = nil
    }

    func calculatePreviousField() {
        focusedField = nil
    }

    func onDismissKeyboard() {
        focusedField = nil
    }

    func handleObsidianTap() {
        do {
            let taskNoteFolderBookmark: Data? = UserDefaultsManager.shared.getValue(forKey: .taskNoteFolderBookmark)
            if taskNoteFolderBookmark == nil {
                isShowingObsidianSettings = true
                return
            }
            if !storeKit.hasPremiumAccess() {
                globalState.isShowingPaywall = true
                return
            }
            if task.hasNote {
                let noteUrl = try? FileService.shared.createObsidianNote(
                    for: task.obsidianNote ?? "",
                    taskStatus: task.status
                )
                guard let noteUrl else {
                    isShowingAlert = true
                    alertTitle = "There was an error"
                    alertMessage =
                        "Failed to create task note. Please check your Obsidian vault and path settings and try again."
                    return
                }
                _ = noteUrl

                showNoteView = true
                return
            }
            let taskNote = task.description.replacing(" ", with: "-")
            let newTask = TCTask(
                uuid: task.uuid,
                project: task.project,
                description: task.description,
                status: task.status,
                priority: task.priority,
                due: task.due,
                obsidianNote: taskNote
            )
            let noteUrl = try? FileService.shared.createObsidianNote(for: taskNote, taskStatus: task.status)

            guard let noteUrl else {
                isShowingAlert = true
                alertTitle = "There was an error"
                alertMessage =
                    "Failed to create task note. Please check your Obsidian vault and path settings and try again."
                return
            }

            _ = noteUrl

            try TaskchampionService.shared.updateTask(newTask)
            task = newTask

            showNoteView = true
            return
        } catch {
            isShowingAlert = true
            alertTitle = "There was an error"
            alertMessage =
                "Failed to create task note. Please check your Obsidian vault and path settings and try again."
        }
    }

    func handleStartStopTap() {
        do {
            globalState.isSyncingTasks = true
            if task.isActive {
                try TaskchampionService.shared.stopTask(task.uuid) {
                    globalState.isSyncingTasks = false
                }
                task = try TaskchampionService.shared.getTask(uuid: task.uuid)
                return
            }
            try TaskchampionService.shared.startTask(task.uuid) {
                globalState.isSyncingTasks = false
            }
            task = try TaskchampionService.shared.getTask(uuid: task.uuid)
        } catch {
            isShowingAlert = true
            alertTitle = "There was an error"
            alertMessage = "Failed to \(task.isActive ? "stop" : "start") task. Please try again."
        }
    }

    func handleTaskActionTap() {
        do {
            globalState.isSyncingTasks = true
            let newStatus: TCTask.Status = task.isCompleted ? .pending : task
                .isDeleted ? .pending : .completed
            try TaskchampionService.shared.updatePendingTasks(
                [task.uuid],
                withStatus: newStatus
            ) {
                globalState.isSyncingTasks = false
            }
            if (newStatus == .completed) || (newStatus == .deleted) {
                NotificationService.shared.deleteReminderForTask(task: task)
            } else {
                NotificationService.shared.createReminderForTask(task: task)
            }
            dismiss()
        } catch {
            isShowingAlert = true
            alertTitle = "There was an error"
            alertMessage = "Task failed to update. Please try again."
        }
    }

    func updateTask() {
        if description.isEmpty {
            isShowingAlert = true
            alertTitle = "Missing field"
            alertMessage = "Please enter a task name"
            return
        }

        let date: Date? = didSetDate ? due : nil
        let time: Date? = didSetTime
            ? time
            : (didSetDate ? UserDefaultsManager.standard.defaultDueTime() : nil)
        let finalDate = Calendar.current.mergeDateWithTime(date: date, time: time)
        let tags = tags.isEmpty ? nil : tags

        let task = TCTask(
            uuid: task.uuid,
            project: project.isEmpty ? nil : project,
            description: description,
            status: status,
            priority: priority == .none ? nil : priority,
            due: finalDate,
            tags: tags,
            recur: task.recur
        )

        do {
            globalState.isSyncingTasks = true
            try TaskchampionService.shared.updateTask(task) {
                globalState.isSyncingTasks = false
            }
            NotificationService.shared.createReminderForTask(task: task)
            dismiss()
        } catch {
            isShowingAlert = true
            alertTitle = "There was an error"
            alertMessage = "Task failed to update. Please try again."
        }
    }

    func saveAnnotation(_ text: String, for target: AnnotationEditorTarget) {
        do {
            globalState.isSyncingTasks = true
            let onSync = { globalState.isSyncingTasks = false }
            let updatedTask: TCTask
            if let annotation = target.annotation {
                updatedTask = try TaskchampionService.shared.editAnnotation(
                    annotation,
                    newDescription: text,
                    inTask: task.uuid,
                    onSync: onSync
                )
            } else {
                updatedTask = try TaskchampionService.shared.addAnnotation(text, toTask: task.uuid, onSync: onSync)
            }
            // Only take over the annotations so unsaved edits of the other fields stay untouched.
            withAnimation {
                task.annotations = updatedTask.annotations
            }
        } catch {
            globalState.isSyncingTasks = false
            isShowingAlert = true
            alertTitle = "There was an error"
            alertMessage = "Failed to save annotation. Please try again."
        }
    }

    func annotationDeleteAction(for target: AnnotationEditorTarget) -> (() -> Void)? {
        guard let annotation = target.annotation else {
            return nil
        }
        return { removeAnnotation(annotation) }
    }

    func removeAnnotation(_ annotation: TCAnnotation) {
        do {
            globalState.isSyncingTasks = true
            let updatedTask = try TaskchampionService.shared.removeAnnotation(annotation, fromTask: task.uuid) {
                globalState.isSyncingTasks = false
            }
            withAnimation {
                task.annotations = updatedTask.annotations
            }
        } catch {
            globalState.isSyncingTasks = false
            isShowingAlert = true
            alertTitle = "There was an error"
            alertMessage = "Failed to delete annotation. Please try again."
        }
    }

    func deleteTask() {
        do {
            globalState.isSyncingTasks = true
            try TaskchampionService.shared.updatePendingTasks([task.uuid], withStatus: .deleted) {
                globalState.isSyncingTasks = false
            }
            NotificationService.shared.deleteReminderForTask(task: task)
            dismiss()
        } catch {
            isShowingAlert = true
            alertTitle = "There was an error"
            alertMessage = "Task failed to update. Please try again."
        }
    }
}
