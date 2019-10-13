//
//  ViewController.swift
//  bindPDF
//
//  Created by Vishal Telangre on 10/12/19.
//  Copyright © 2019 Vishal Telangre. All rights reserved.
//

import Cocoa
import PDFKit

class ViewController: NSViewController {
    @IBOutlet weak var noPdfFilesContainerView: NSView!
    @IBOutlet weak var pdfFilesContainerView: NSView!
    @IBOutlet weak var pdfFileListTableView: NSTableView!
    @IBOutlet weak var pdfPreviewView: PDFView!
    
    @IBAction func addButton(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["pdf", "PDF"]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.beginSheetModal(for: self.view.window!) { (response) in
            if response == .OK {
                for url in openPanel.urls {
                    self.urls.append(url)
                }
            }
            
            self.pdfFileListTableView.reloadData()
            
            openPanel.close()
            
            self.reloadLivePreview()
        }
    }
    
    @IBAction func export(_ sender: NSButton) {
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["pdf", "PDF"]
        savePanel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        savePanel.beginSheetModal(for: self.view.window!) { (response) in
            if response == .OK {
                self.pdfPreviewView.document?.write(to: savePanel.url!)
                savePanel.close()
                
                self.urls = []
                self.pdfFileListTableView.reloadData()
                self.reloadLivePreview()
            }

        }
    }
    
    let pasteboardType = NSPasteboard.PasteboardType(rawValue: "bindPDF.url")
    var urls: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        pdfFilesContainerView.isHidden = true
        pdfFileListTableView.delegate = self
        pdfFileListTableView.dataSource = self
        pdfFileListTableView.registerForDraggedTypes([pasteboardType])
    }

    func reorderFile(at: Int, to: Int) {
        pdfFileListTableView.delegate = nil
        urls.insert(urls.remove(at: at), at: to)
        pdfFileListTableView.delegate = self
        
        reloadLivePreview()
    }
    
    func reloadLivePreview() {
        pdfFilesContainerView.isHidden = urls.count == 0
        noPdfFilesContainerView.isHidden = urls.count != 0
        
        if urls.count == 0 {
            return
        }
        
        var pageIndex = 0
        let previewDocument = PDFDocument()
        
        for url in urls {
            if let document = PDFDocument(url: url) {
                for pageNumber in 1...document.pageCount {
                    if let page = document.page(at: pageNumber - 1) {
                        previewDocument.insert(page, at: pageIndex)
                        pageIndex += 1
                    }
                }
            }
        }
        
        pdfPreviewView.document = previewDocument
    }
}

extension ViewController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 300
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedMaximumPosition - 900
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return urls.count
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let url = urls[row]
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(url.path, forType: pasteboardType)
        return pasteboardItem
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        } else {
            return []
        }
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard
            let item = info.draggingPasteboard.pasteboardItems?.first,
            let theString = item.string(forType: pasteboardType),
            let url = urls.first(where: { $0.path == theString }),
            let originalRow = urls.firstIndex(of: url)
            else {
                return false
            }
        
        var newRow = row
        if originalRow < newRow {
            newRow = row - 1
        }
        
        // Animate the rows
        pdfFileListTableView.beginUpdates()
        pdfFileListTableView.moveRow(at: originalRow, to: newRow)
        pdfFileListTableView.endUpdates()
        
        // Update the data model
        reorderFile(at: originalRow, to: newRow)
        
        return true
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let url = urls[row]
        if let cell = pdfFileListTableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "defaultCell"), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = url.lastPathComponent
            cell.textField?.maximumNumberOfLines = 4

            let pdfDocument = PDFDocument(url: url)
            if let firstPage = pdfDocument?.page(at: 0) {
                cell.imageView?.image = firstPage.thumbnail(of: NSSize(width: 256, height: 256), for: .artBox)
            }
            
            return cell
        }
        
        return nil
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        let action = NSTableViewRowAction(style: .destructive, title: "Delete") { (action, row) in
            self.urls.remove(at: row)
            self.pdfFileListTableView.removeRows(at: IndexSet(integer: row), withAnimation: .effectFade)
            self.reloadLivePreview()
        }
        
        return [action]
    }
}
