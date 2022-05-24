import Foundation
import Combine

struct CocktailProvider {
    let searchCocktail: (String) async throws -> [CocktailAPI.Cocktail]
}

extension CocktailProvider {
    static let mock: Self = .init(searchCocktail: { _ in
        return .mock
    })
}

class CocktailService {
    
    var favoritesPublisher: AnyPublisher<[CocktailAPI.Cocktail], Never> {
        favoritesSubject.eraseToAnyPublisher()
    }
    
    private(set) var cocktails: Set<CocktailAPI.Cocktail> = []
    private(set) var favorites: [CocktailAPI.Cocktail] = []
    
    private let favoritesSubject: PassthroughSubject<[CocktailAPI.Cocktail], Never> = .init()
    private let cocktailProvider: CocktailProvider
    
    init(cocktailProvider: CocktailProvider) {
        self.cocktailProvider = cocktailProvider
    }
    
    func toggleFavorite(cocktail: CocktailAPI.Cocktail) {
        if let index = favorites.firstIndex(where: { $0.idDrink == cocktail.idDrink }) {
            favorites.remove(at: index)
        } else {
            favorites.append(cocktail)
        }
        favoritesSubject.send(favorites)
        
    }
    
    func isFavorite(_ id: String) -> Bool {
        return favorites.contains(where: { id == $0.idDrink })
    }
    
    func search(cocktail: String) async throws -> [CocktailAPI.Cocktail] {
        let fetched = try await cocktailProvider.searchCocktail(cocktail)
        cocktails.formUnion(Set(fetched))
        return fetched
    }
}

extension CocktailService {
    static let mock = CocktailService(cocktailProvider: .mock)
}
