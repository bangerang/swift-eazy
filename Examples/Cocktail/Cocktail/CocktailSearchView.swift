import SwiftUI
import Eazy
import Combine

struct CocktailSearchState: Equatable {
    var isListingFavourites: Bool {
        return searchString.isEmpty
    }
    var searchString: String = ""
    var cocktails: [CocktailSearchView.Cocktail] = []
    var errorMessage: String? = nil
    var loading: Bool = false
}

enum CocktailSearchAction: Equatable, CancellableAction {
    case searchCocktail(String)
    case toggleFavorite(CocktailSearchView.Cocktail)
    
    var cancelIdentifier: String? {
        switch self {
        case .searchCocktail:
            return "searchCocktail"
        case .toggleFavorite:
            return nil
        }
    }
}

enum CocktailSearchHook: CaseIterable {
    case favoritesChanged
    case searchStringChanged
}

struct CocktailSearchInteractor: Interactor {
    
    let service: CocktailService

    func onAction(_ action: CocktailSearchAction, store: MutatingStore<CocktailSearchState, CocktailSearchAction>) async {
        store.errorMessage = nil
        switch action {
        case .searchCocktail(let query):
            await searchCocktail(query: query, store: store)
        case .toggleFavorite(let cocktail):
            if let found = service.cocktails.first(where: { $0.idDrink == cocktail.id }) {
                service.toggleFavorite(cocktail: found)
            }
        }
    }

    func publisher(for hook: CocktailSearchHook, store: MutatingStore<CocktailSearchState, CocktailSearchAction>) -> AnyCancellable {
        switch hook {
        case .favoritesChanged:
            return HookPublisher(service.favoritesPublisher)
                .sink { _ in
                    withAnimation(.linear(duration: 0.2)) {
                        let cocktails = store.cocktails
                        for (index, cocktail) in cocktails.enumerated().reversed() {
                            if service.isFavorite(cocktail.id) {
                                store.cocktails[index].isFavorite = true
                            } else {
                                if store.isListingFavourites {
                                    store.cocktails.remove(at: index)
                                } else {
                                    store.cocktails[index].isFavorite = false
                                }
                            }
                        }
                    }
                }
        case .searchStringChanged:
            return HookPublisher(store.publisher.searchString)
                .debounce(for: 0.3, scheduler: DispatchQueue.main)
                .assign(toAction: { .searchCocktail($0) }, using: store)
        }
    }

    private func searchCocktail(query: String, store: MutatingStore<CocktailSearchState, CocktailSearchAction>) async {
        if store.isListingFavourites {
            let result = service.favorites.map {
                CocktailSearchView.Cocktail(from: $0, isFavorite: true)
            }
            store.cocktails = result
        } else {
            store.cocktails = []
            store.loading = true
            do {
                let cocktails = try await service.search(cocktail: query)
                let result = cocktails.map {
                    CocktailSearchView.Cocktail(from: $0, isFavorite: service.isFavorite($0.idDrink))
                }
                store.cocktails = result
            } catch {
                if !Task.isCancelled {
                    store.errorMessage = error.localizedDescription
                }
            }
            store.loading = false
        }
    }
}

struct CocktailSearchView: View {
    @StateStore var store: Store<CocktailSearchState, CocktailSearchInteractor.Action>
    
    var body: some View {
        NavigationView {
            ZStack {
                List(store.cocktails) { cocktail in
                    NavigationLink {
                        CocktailDetailsView(store: makeStore(from: cocktail))
                    } label: {
                        CocktailItem(name: cocktail.name,
                                     thumbnailLink: cocktail.thumbnailLink,
                                     isFavorite: cocktail.isFavorite)
                    }
                    .swipeActions {
                        Button(cocktail.isFavorite ? "Remove" : "Favorite") {
                            store.dispatch(.toggleFavorite(cocktail))
                        }
                        .tint(cocktail.isFavorite ? .red : .green)
                    }
                }
                .searchable(text: $store.searchString)
                .disableAutocorrection(true)
                
                if store.loading {
                    ProgressView()
                } else if let error = store.errorMessage {
                    Text(error)
                }
            }
            .navigationTitle("Cocktails")
        }
    }
    
    func makeStore(from cocktail: Cocktail) -> Store<CocktailDetailsState, CocktailDetailsInteractor.Action> {
        let state = CocktailDetailsState(imageLink: cocktail.imageLink,
                                         id: cocktail.id,
                                         name: cocktail.name,
                                         instruction: cocktail.description,
                                         isFavorite: cocktail.isFavorite)

        return Store(state: state,
                     interactor: CocktailDetailsInteractor(service: service))
    }
}

struct CocktailItem: View {
    let name: String
    let thumbnailLink: String?
    let isFavorite: Bool
    
    var body: some View {
        HStack {
            if let thumbnailLink = thumbnailLink {
                AsyncImage(url: URL(string: thumbnailLink)) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .cornerRadius(8)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .cornerRadius(8)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .cornerRadius(8)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
            }
            Text(name)
        }
    }
}

extension CocktailSearchView {
    
    struct Cocktail: Identifiable, Equatable {
        let id: String
        let name: String
        let description: String
        var isFavorite: Bool
        let thumbnailLink: String?
        let imageLink: String?
        
        init(from: CocktailAPI.Cocktail, isFavorite: Bool) {
            self.id = from.idDrink
            self.name = from.strDrink
            self.description = from.strInstructions
            self.thumbnailLink = from.strDrinkThumb
            self.imageLink = from.strImageSource
            self.isFavorite = isFavorite
        }
    }
}

extension CocktailSearchView.Cocktail {
    static var mockFavorite: CocktailSearchView.Cocktail {
        return CocktailSearchView.Cocktail(from: .mock, isFavorite: true)
    }
    static var mockNonFavorite: CocktailSearchView.Cocktail {
        return CocktailSearchView.Cocktail(from: .mock, isFavorite: false)
    }
}

#if DEBUG
struct CocktailSearchView_Previews: PreviewProvider {
    static var previews: some View {
        CocktailSearchView(store: Store(state: CocktailSearchState(),
                                        interactor: CocktailSearchInteractor(service: .mock)))
    }
}
#endif
