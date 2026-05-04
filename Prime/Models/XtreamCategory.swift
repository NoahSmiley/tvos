import Foundation

struct XtreamCategory: Codable, Identifiable {
    let categoryId: String
    let categoryName: String
    let parentId: Int

    var id: String { categoryId }

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case parentId = "parent_id"
    }
}
