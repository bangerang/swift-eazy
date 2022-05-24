import XCTest
import Eazy
import Combine
@testable import Cocktail

class CocktailSearchTests: XCTestCase {
    
    @MainActor
    func testSearchCocktail() async {
        let testStore = TestStore(state: CocktailSearchState(),
                                  interactor: CocktailSearchInteractor(service: .mock))
        
        testStore.searchString = "Foo"
        
        let didTrigger = await testStore.didTrigger(.searchCocktail("Foo"))
        
        XCTAssertTrue(didTrigger)
        
        var state = CocktailSearchState(searchString: "Foo")
        
        let expectedUpdates: [CocktailSearchState] = [
            state,
            state.with {
                $0.loading = true
            },
            state.with {
                $0.cocktails = [.mockNonFavorite]
            },
            state.with {
                $0.loading = false
            }
        ]
        
        XCTAssertEqual(expectedUpdates, testStore.stateUpdates)
    }
    
    @MainActor
    func testEmptySearchShouldDisplayFavorites() async {
        
        let service = CocktailService(cocktailProvider: .mock)
        service.toggleFavorite(cocktail: .mock)
        
        let testStore = TestStore(state: CocktailSearchState(searchString: "Foo"),
                                  interactor: CocktailSearchInteractor(service: service))
        
        testStore.searchString = ""
        
        let didTrigger = await testStore.didTrigger(.searchCocktail(""))
        
        XCTAssertTrue(didTrigger)
        
        let expected = CocktailSearchState(searchString: "",
                                           cocktails: [.mockFavorite],
                                           errorMessage: nil,
                                           loading: false)
        
        XCTAssertEqual(expected, testStore.state)
        
    }
    
    @MainActor
    func testToggleFavorite() async throws {
        let service = CocktailService(cocktailProvider: .mock)
        _ = try await service.search(cocktail: "Foo")
        let state = CocktailSearchState(searchString: "Foo", cocktails: service.cocktails.map {
            .init(from: $0, isFavorite: false) }
        )
        
        let testStore = TestStore(state: state,
                                  interactor: CocktailSearchInteractor(service: service))
        
        await testStore.dispatch(.toggleFavorite(.mockNonFavorite))
        
        XCTAssertTrue(service.favorites == [.mock])
    }
    
}
