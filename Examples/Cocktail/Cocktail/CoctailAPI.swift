import Foundation

struct CocktailAPI {
    struct Drinks: Decodable {
        let drinks: [Cocktail]
    }
    struct Cocktail: Decodable, Hashable {
        let idDrink: String
        let strDrink: String
        let strInstructions: String
        let strImageSource: String?
        let strDrinkThumb: String?
    }
    
    func searchCocktail(query: String) async throws -> [Cocktail] {
        guard let urlEncoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            fatalError()
        }
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://www.thecocktaildb.com/api/json/v1/1/search.php?s=\(urlEncoded)")!)
        let decoder = JSONDecoder()
        return try decoder.decode(Drinks.self, from: data).drinks
    }
}

extension Array where Element == CocktailAPI.Cocktail {
    static var mock: [CocktailAPI.Cocktail] {
        [.mock]
    }
}

extension CocktailAPI.Cocktail {
    static var mock = CocktailAPI.Cocktail(idDrink: "12", strDrink: "Vodka", strInstructions: "Some instructions", strImageSource: nil, strDrinkThumb: nil)
}
