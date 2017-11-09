port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Decimal as Dec exposing (Decimal)


main =
    Html.programWithFlags
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type Payment
    = Unpaid
    | Paying
    | Paid String { signature : String, message : String }


type SelectedAccount
    = Payee
    | NonPayee


type Validity a
    = Valid a
    | Invalid String



-- MODEL


type alias Model =
    { ethereum : Bool
    , payee : String
    , selectedAccount : Maybe SelectedAccount
    , percent : Maybe String
    , payment : Payment
    , amount : Maybe (Validity String)
    , donee : Maybe (Validity String)
    }


init : { ethereum : Bool, payee : String } -> ( Model, Cmd Msg )
init { ethereum, payee } =
    ( { ethereum = ethereum
      , payee = payee
      , selectedAccount = Nothing
      , percent = Nothing
      , payment = Unpaid
      , amount = Nothing
      , donee = Nothing
      }
    , Cmd.none
    )



-- PORTS


port portsReady : (() -> msg) -> Sub msg


port ethereum : (Bool -> msg) -> Sub msg


port getPercent : () -> Cmd msg


port gotPercent : (String -> msg) -> Sub msg


port validateAmount : String -> Cmd msg


port amountValidity : ({ value : String, validity : String } -> msg) -> Sub msg


port validateDoneeAddress : String -> Cmd msg


port doneeAddressValidity : ({ value : String, validity : String } -> msg) -> Sub msg


port selectedAccount : (Maybe String -> msg) -> Sub msg


port pay : { amount : String, donee : String } -> Cmd msg


port paying : (() -> msg) -> Sub msg


port paid : ({ txHash : String, signature : { signature : String, message : String } } -> msg) -> Sub msg



-- SUBSCRIPTIONS


subscriptions model =
    Sub.batch
        [ portsReady PortsReady
        , ethereum Ethereum
        , gotPercent GotPercent
        , amountValidity AmountValidity
        , doneeAddressValidity DoneeAddressValidity
        , selectedAccount SelectedAccount
        , paying TxHash
        , paid Receipt
        ]


type Msg
    = -- Paying and Paid changed to TxHash and Receipt to avoid conflict with type Payment
      PortsReady ()
    | Ethereum Bool
    | GotPercent String
    | Amount String
    | Donee String
    | AmountValidity { value : String, validity : String }
    | DoneeAddressValidity { value : String, validity : String }
    | SelectedAccount (Maybe String)
    | Pay String String
      -- TxHash is paying
    | TxHash ()
      -- Receipt is paid
    | Receipt { txHash : String, signature : { signature : String, message : String } }



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PortsReady _ ->
            ( model
            , if model.ethereum then
                getPercent ()
              else
                Cmd.none
            )

        Ethereum present ->
            if present then
                ( { model | ethereum = True }, getPercent () )
            else
                ( { model | ethereum = False }, Cmd.none )

        GotPercent percent ->
            ( { model | percent = Just percent }, Cmd.none )

        Amount input ->
            case input of
                "" ->
                    ( { model | amount = Nothing }, Cmd.none )

                _ ->
                    ( model, validateAmount input )

        AmountValidity { value, validity } ->
            ( { model
                | amount =
                    Just
                        (case validity of
                            "valid" ->
                                Valid value

                            _ ->
                                Invalid "amount"
                        )
              }
            , Cmd.none
            )

        Donee input ->
            case input of
                "" ->
                    ( { model | donee = Nothing }, Cmd.none )

                _ ->
                    ( model, validateDoneeAddress input )

        DoneeAddressValidity { value, validity } ->
            ( { model
                | donee =
                    Just
                        (case validity of
                            "valid" ->
                                Valid value

                            _ ->
                                Invalid "address or donee"
                        )
              }
            , Cmd.none
            )

        SelectedAccount account ->
            ( { model
                | selectedAccount =
                    case account of
                        Just account ->
                            if String.toLower account == model.payee then
                                -- HACK find out why account is checksum address, not lower case address
                                Just Payee
                            else
                                Just NonPayee

                        _ ->
                            Nothing
              }
            , Cmd.none
            )

        Pay amount donee ->
            ( model
            , case model.selectedAccount of
                -- has to be checked here as it's possible to click OK in the 100ms after the selected account is changed.
                Just NonPayee ->
                    pay { amount = amount, donee = donee }

                _ ->
                    Cmd.none
            )

        TxHash _ ->
            ( { model | payment = Paying }, Cmd.none )

        Receipt { txHash, signature } ->
            ( { model | payment = Paid txHash { signature = signature.signature, message = signature.message } }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ div [] [ h3 [] [ a [ href "mailto:w.white9@icloud.com" ] [ text "email" ] ] ]
        , div [] [ h3 [] [ text "pay" ] ]
        , div [] (y model)
        ]



-- VIEW HELPERS


y model =
    if model.ethereum then
        case model.percent of
            Nothing ->
                [ text "getting %" ]

            Just percent ->
                case model.payment of
                    Unpaid ->
                        form model percent

                    Paying ->
                        [ text "paying" ]

                    Paid txHash { signature, message } ->
                        [ text ("paid: Save this receipt: transaction: " ++ txHash ++ " signature: " ++ signature ++ " message: " ++ message) ]
    else
        [ text "Install MetaMask" ]


form model percent =
    case model.selectedAccount of
        Just NonPayee ->
            case model.amount of
                Just (Valid amount) ->
                    fields percent model.donee
                        ++ (case model.donee of
                                Just (Valid donee) ->
                                    [ button [ onClick (Pay amount donee) ] [ text "OK" ] ]

                                _ ->
                                    disabledButton
                           )

                _ ->
                    disabledForm percent model.donee

        Just Payee ->
            [ div [] [ text "Payee's account selected in MetaMask. Switch account." ] ] ++ disabledForm percent model.donee

        Nothing ->
            [ div [] [ text "Unlock MetaMask" ] ] ++ disabledForm percent model.donee


disabledForm percent donee =
    fields percent donee ++ disabledButton


disabledButton =
    [ button [ disabled True ] [ text "OK" ] ]


fields percent donee =
    [ label [ style [ ( "display", "block" ) ] ]
        [ text "amount ", input [ type_ "number", Html.Attributes.min "0", onInput Amount ] [], text " ETH" ]
    , doneeInput percent donee
    ]


doneeInput percent donee =
    label [ style [ ( "display", "block" ) ] ]
        (case donee of
            Just (Invalid reason) ->
                [ text ("donate " ++ percent ++ "% to ")
                , input [ type_ "text", placeholder "Ethereum address", onInput Donee ] []
                , text ("invalid " ++ reason)
                ]

            _ ->
                [ text ("donate " ++ percent ++ "% to ")
                , input [ type_ "text", placeholder "Ethereum address", onInput Donee ] []
                ]
        )
