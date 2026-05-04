import Foundation

protocol SidebarDelegate: AnyObject {
    func sidebarDidSelectDestination(_ destination: SidebarDestination)
    func sidebarDidRequestToggle()
}
