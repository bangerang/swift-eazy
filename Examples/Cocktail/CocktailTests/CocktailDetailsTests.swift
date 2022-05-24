import XCTest
import Eazy
import Combine
@testable import Cocktail

class CocktailDetailsTests: XCTestCase {
    @MainActor
    func testFavoriteGetsUpdated() async throws {
        let service = CocktailService(cocktailProvider: .mock)
        let mock = CocktailSearchView.Cocktail.mockNonFavorite
        let state = CocktailDetailsState(imageLink: nil, id: mock.id, name: mock.name, instruction: mock.description, isFavorite: false)
        
        let testStore = await TestStore.testHook(.favoriteChanged,
                                                 trigger: service.toggleFavorite(cocktail: .mock),
                                                 state: state,
                                                 interactor: CocktailDetailsInteractor(service: service))
        
        XCTAssertTrue(testStore.state.isFavorite)
    }
}
