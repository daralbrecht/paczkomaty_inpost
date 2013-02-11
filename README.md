# PaczkomatyInpost

## Opis użytkowania:

Utwórz obiekt api:

```ruby
data_adapter = PaczkomatyInpost::FileAdapter.new(path_to_folder)
@api = PaczkomatyInpost::InpostAPI.new(username,password,data_adapter)
```

W przypadku problemów z połączeniem się z API Paczkomatów gem zaalarmuje o problemie w postaci wywołania Timeout::Error z wiadomością o braku połączenia.

API obsługuje metody opisane poniżej.

### inpost_get_params

Pobiera podstawowe parametry systemu Paczkomaty. Zapisane są one w postaci hashu w @api.params.
Parametry to:
- logo_url - link do logotypu InPost paczkomaty24/7
- info_url – link do informacji
- rules_url – link do regulaminu
- register_url – link do rejestracji
- last_update – timestamp ostatniej aktualizacji bazy danych
- current_api_version – wersja gemu


### inpost_machines_cache_is_valid?(update_params=true)

Sprawdzenie czy lista lokalnie zapisanych paczkomatów nie jest przedawniona. Do sprawdzenia wykorzystuje parametr @api.params[:last_update]. Jeśli przekazana zostanie wartość true jako parametr przy wywołaniu to metoda uaktualni najpierw parametry z systemu InPost Paczkomaty.


### inpost_prices_cache_is_valid?(update_params=true)

Analogicznie jak sprawdzanie listy paczkomatów, metoda ta sprawdza lokalnie zapisane cenniki.


### inpost_update_machine_list(update_params=false)

Ściąga kompletną listę Paczkomatów i zapisuje ją we wskazanym data adapterze.


### inpost_update_price_list(update_params=false)

Pobiera cennik i zapisuje go w adapterze.


### inpost_get_machine_list(options={})

Wyświetlenie paczkomatów w postaci tablicy zawierającej hashe z parametrami paczkomatów.

Przykład paczkomatu:
```ruby
machine = {
  "name" => "GDY028",
  "street" => "Morska",
  "buildingnumber" => "290",
  "postcode" => "81-002",
  "town" => "Gdynia",
  "latitude" => "54.5505",
  "longitude" => "18.42789",
  "paymentavailable" => true,
  "operatinghours" => "Paczkomat: 24/7",
  "locationdescription" => "Stacja paliw LUKOIL po prawej stronie w kierunku Rumi",
  "paymentpointdescr" => "Płatność kartą wyłącznie w paczkomacie. Dostępność: 24/7",
  "partnerid" => 2,
  "paymenttype" => 2,
  "type" => "Pack Machine"
}
```

Możliwe opcje do przekazania to :town oraz :paymentavailable. W przypadku wskazania miasta - tylko paczkomaty z danego miasta zostaną wymienione. Paymentavailable określa czy wyświetlane paczkomaty mają obsługiwać pobranie.

Przykład:
```ruby
@api.inpost_get_machine_list(:town => 'Gdynia', :paymentavailable => true)
```


### inpost_get_pricelist

Metoda zwraca hash zawierający informacje o płatnościach takich jak: minimalny koszt dodatkowy nadania przesyłki za probraniem (on_delivery_payment), maksymalny koszt dodatkowy nadania przesyłki za pobraniem (on_delivery_limit), procentowej wartości pobrania (on_delivery_percentage), ceny przzesyłek o standardowych wielkościach A, B oraz C. Ceny podane są w PLN.

Dodatkowo klucz insurence zawiera hash z informacjami na temat cennika ubezpieczeń dla poszczególnych limitów kwoty ubezpieczenia.

Przykład:
```ruby
prices = {
  "on_delivery_payment" => "3.50",
  "on_delivery_percentage" => "1.80",
  "on_delivery_limit" => "5000.00",
  "A" => "6.99",
  "B" => "8.99",
  "C" => "11.99",
  "insurance" => {"5000.00" => "1.50", "10000.00" => "2.50", "20000.00" => "3.00"}
}
```


### inpost_get_towns

Tablica zawierająca nazwy miejscowości, w których znajdują się Paczkomaty InPost.


### inpost_find_nearest_machines(postcode,paymentavailable=nil)

Zwraca tablice zawierającą 3 najbliższe paczkomaty dla przekazanego kodu pocztowego. Przyjmuje również opcjonalny parametr paymentavailable zawężający wyszukiwanie do paczkomatów obsługujących pobranie.


### inpost_find_customer(email)

Sprawdza czy wskazany email znajduje się w bazie użytkowników Paczkomatów InPost. W przypadku odnalezienia zwraca hash z informacjami na temat preferowanych paczkomatów:

```ruby
{"preferedBoxMachineName" => "KRA010", "alternativeBoxMachineName" => "AND039"}
```

Jeśli użytkownika nie odnaleziono, zwrócony zostaje błąd:

```ruby
{"error" => {"OtherException" => "Klient nie istnieje paczkomaty_test@example.com"}}
```


### inpost_prepare_pack(temp_id, adresee_email, phone_num, box_machine_name, pack_type, insurance_amount, on_delivery_amount, options={})

Metoda przygotowuje paczkę do wysyłki (zwraca obiekt klasy InpostPack). Wymagane parametry to:
- temp_id - tymczasowy identyfikator paczki,
- adresee_email - adres email odbiorcy,
- phone_num - numer telefonu odbiorcy,
- box_machine_name - oznaczenie paczkomatu,
- pack_type - typ paczki,
- insurance_amount - kwota ubezpieczenia
- on_delivery_amount - kwota pobrania

Poza tym dopuszczalne są opcje:
- customer_ref - dodatkowa informacja do umieszczenia na etykiecie,
- alternative_box_machine_name - oznaczenie alternatywnego paczkomatu,
- customer_delivering - wysyłka z paczkomatu nadawczego,
- sender_address - hash za następującymi parametrami do umieszczenia na etykiecie:
  - name => imię nadawcy,
  - surname => nazwisko nadawcy,
  - email => adres email,
  - phone_num => numer telefonu nadawcy,
  - street => ulica,
  - building_no => numer budynku nadawcy,
  - flat_no => numer lokalu,
  - town => miasto,
  - zip_code => kod pocztowy nadawcy,
  - province => województwo nadawcy

Przykład utworzenia:

```ruby
sender = {:name => 'Sender', :surname => 'Tester', :email => 'test@testowy.pl', :phone_num => '578937487',
          :street => 'Test Street', :building_no => '12', :flat_no => nil, :town => 'Test City',
          :zip_code => '67-248', :province => 'pomorskie'}
pack = @api.inpost_prepare_pack('pack_1', 'test01@paczkomaty.pl', '501892456', 'KRA010',
          'B', '1.5', '10.99', :customer_ref => 'testowa przesyłka', :sender_address => sender)
```


### inpost_send_packs(packs_data, options = {})

Rejestruje paczki do wysłania w systemie Paczkomaty. Jako packs_data przekazana może być pojedynczy obiekt klasy InpostPack lub ich tablica.
Dozwolone opcje:
- :auto_labels - określa czy utworzone przesyłki mają mieć status ustawiony automatycznie na Prepared czy pozostawione na Created (default true),
- :self_send - określa czy przesyłka będzie nadawana w oddziale (false) czy bezpośrednio w paczkomacie (true) (default false).

Metoda zwraca hash z przypisanymi packcode dla poszczególnych paczek (identyfikatorami są temp_id). W przypadku błędu przy danej paczce zwracany jest typ oraz opis błędu.

Przykład zwróconej wartości:
```ruby
{
  "pack_1"=>
  {
    "packcode" => "622222042330624327700110"
  },
  "pack_2"=>
  {
    "error_key" => "IllegalPackType",
    "error_message" => "Illegal or empty pack type."
  }
}
```


### inpost_get_pack_status(packcode)

Zwraca status przesyłki dla wskazanego packcode.
Dopuszczalne zwracane wartości:
- Created - oczekuje na wysyłkę
- Prepared - gotowa do wysyłki
- Sent - przesyłka nadana
- InTransit - w drodze
- Stored - oczekuje na odbiór
- Avizo - ponowne avizo
- Expired - nie odebrana
- Delivered – dostarczona
- RetunedToAgency - przekazana do oddziału
- Cancelled – anulowana
- Claimed - przyjęto zgłoszenie reklamacyjne
- ClaimProcessed - rozpatrzono zgłoszenie reklamacyjne

Przykłady zwracanych wartości:
```ruby
# Prawidłowy packcode
{"status"=>"Prepared"}

# Błędny packcode
{"error" => {"PACK_NO_ERROR" => "Błędny numer paczki"}}

```


### inpost_cancel_pack(packcode)

Metoda umożliwia anulowanie paczki będącej w statusie Created (nieopłacone).

Zwraca true w przypadku anulowania, false w przeciwnym razie oraz błąd w postaci String'a w przypadku błędnych danych.


### inpost_change_packsize(packcode, packsize)

Zmienia gabaryty wskazanej paczki. Paczka musi posiadac status Created by operacja powiodła się. Dopuszczalne wartości dla packsize to 'A', 'B' oraz 'C'.

Zwraca true w przypadku zmiany, false w przeciwnym razie oraz błąd w postaci String'a w przypadku błędnych danych.


### inpost_pay_for_pack(packcode)

Zmienia status paczki ze statusu Created do Prepared lub CustomerDelivering (dla paczek do samodzielnego nadania) pobierając jednocześnie opłatę za nadanie. Tylko paczki w statusie Prepared lub CustomerDelivering mogą zostać nadane.

Zwraca true w przypadku zmiany, false w przeciwnym razie oraz błąd w postaci String'a w przypadku błędnych danych.


### inpost_set_customer_ref(packcode, customer_ref)

Umieszcza dodatkową informację na etykiecie. Sugerowane zastosowanie to wydruk numeru zamówienia z systemu klienta, aby ułatwić naklejenie właściwej etykiety na odpowiednią paczkę.

Zwraca true w przypadku poprawnego wygenerowania etykiety, false w przeciwnym razie oraz błąd w postaci String'a w przypadku błędnych danych.


### inpost_get_sticker(packcode, options = {})

Pobiera etykietę do umieszczenia na paczce w formacie PDF. Dopuszczalne opcje to:
- sticker_path - ścieżka do zapisu pliku PDF, w przypadku braku wykorzystana zostanie scieżka głowna z data adapter'a,
- label_type - typ etykiety ('' dla standardowego (default), 'A6P' dla etykiety A6 w orientacji poziomej).

Zwraca true w przypadku prawidłowego ściągnięcia i zapisania etykiety (nazwa pliku tworzona przy użyciu wskazanego packcode), false w przeciwnym razie oraz błąd w postaci String'a w przypadku błędnych danych.


### inpost_get_stickers(packcodes, options = {})

Podobnie jak poprzedniczka pozwala pobrać etykietę dla paczki, z tą różnicą iż można do niej przekazać większą liczbą packcode'ów w postaci tablicy. Dopuszczalne opcje to również:
- sticker_path - ścieżka do zapisu pliku PDF, w przypadku braku wykorzystana zostanie scieżka głowna z data adapter'a,
- label_type - typ etykiety ('' dla standardowego (default), 'A6P' dla etykiety A6 w orientacji poziomej).

Zwraca true w przypadku prawidłowego ściągnięcia i zapisania etykiety (nazwa pliku tworzona przy użyciu przekazanych packcode'ów), false w przeciwnym razie oraz błąd w postaci String'a w przypadku błędnych danych.


### inpost_get_confirm_printout(packcodes, options = {})

Pobiera potwierdzenia nadania paczek do wysłania w formacie PDF. Dopuszczalne dodatkowe opcje to:
- printout_path - ścieżka do zapisu pliku PDF, w przypadku braku wykorzystana zostanie scieżka głowna z data adapter'a,
- test_printout - gdy true pozwala na wielokrotne drukowanie próbne, w przypadku false (default) wydruk dopuszczalny tylko raz.

Zwraca true w przypadku prawidłowego ściągnięcia i zapisania potwierdzenia (nazwa pliku tworzona przy użyciu przekazanych packcode'ów), false w przeciwnym razie oraz błąd w postaci String'a w przypadku błędnych danych.


### inpost_create_customer_partner(options={})

Metoda umożliwia zdalną rejestrację klienta w systemie Paczkomaty 24/7.
Wymagane parametry:
- prefered_box_machine_name - paczkomat domyślny
- post_code - kod pocztowy
- email
- phone_num

Parametry opcjonalne:
- mobile_number
- alternative_box_machine_name - paczkomat zapasowy
- street
- town
- building
- flat
- first_name
- last_name
- company_name
- regon
- nip

W przypadku błędu zwrócony zostanie jako wiadomość (String). W przypadku udanego załóżenia konta zwrócony zostanie podany adres mailowy klienta w postaci String'a, a klient otrzyma email z informacją o rejestracji.


### inpost_get_cod_report(options={})

Zwraca informacje o zrealizowanych transakcjach pobraniowych (collect on delivery).
Dopuszczalne opcje:
- start_date - data początku wskazanego okresu,
- end_date - data końcowa wskazanego okresu.
Okres nie może przekraczać 60 dni. W przypadku braku parametrów metoda wskaże okres ostatnich 60 dni.

Zwraca false w przypadku problemów z uzyskaniem odpowiedzi. String z błędem w przypadku zwróconego błędu z API Paczkomatów 24/7.
Prawidłowo zakończona operacja zwraca hash zawierający kolejne paczki:

```ruby
{
  :packcode => {
    :amount => kwota_pobrania,
    :posdesc => opis_punktu_pos,
    :packcode => numer_paczki,
    :transactiondate => data_transakcji
  }
}
```


### inpost_get_packs_by_sender(options={})

! Metoda nie przetestowana! Testy w drodze :)

Metoda pozwala uzyskać informację na temat paczek wygenerowanych w systemie przez określonego nadawcę.
Dopuszczalne opcje:
- status - status paczek,
- start_date - data początkowa,
- end_date - data końcowa,
- is_conf_printed - czy potwierdzenie nadania wydrukowane.

Zwraca hash z odnalezionymi przesyłkami. Kluczami do poszczególnych paczek są packcode'y. Struktura zwróconej paczki wygląda następująco:
```ruby
{
  :packcode => {
    :alternativeboxmachinename => paczkomat_alternatywny,
    :amountcharged => kwota_pobrana_z_konta_nadawcy,
    :calculatedchargeamount => cena_paczki,
    :creationdate => data_utworzenia_paczki, 
    :customerdeliveringcode => kod_samodzielnego_nadania,
    :is_conf_printed => czy_potwierdzenie_nadania_wydrukowane,
    :labelcreationtime => data_wydruku_etykiety,
    :labelprinted => czy_etykieta_wydrukowana,
    :ondeliveryamount => kwota_pobrania,
    :packcode => kod_paczki,
    :packsize => gabaryt_paczki,
    :preferedboxmachinename => docelowy_paczkomat,
    :receiveremail => email_odbiorcy,
    :status => status_paczki
  }
}
```

W przypadku błedu zwraca false (gdy brak lub błędne parametry przekazane) lub wiadomość o błedzie w postaci String'a.



# TODO:
Dalsze testy w drodze :)