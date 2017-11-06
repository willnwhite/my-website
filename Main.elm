port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


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
    | Paid String { signature : String, msg : String }


type SelectedAccount
    = Payee
    | NonPayee



-- MODEL


type alias Model =
    { ethereum : Bool
    , payee : String
    , selectedAccount : Maybe SelectedAccount
    , percent : Maybe Float
    , payment : Payment
    , amount : Maybe Float
    , donee : Maybe String
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


port validateAddress : String -> Cmd msg


port validAddress : ({ input : String, valid : Bool } -> msg) -> Sub msg


port selectedAccount : (Maybe String -> msg) -> Sub msg


port pay : { amount : Float, donee : String } -> Cmd msg


port paying : (() -> msg) -> Sub msg


port paid : ({ txHash : String, signature : { signature : String, msg : String } } -> msg) -> Sub msg



-- SUBSCRIPTIONS


subscriptions model =
    Sub.batch
        [ portsReady PortsReady
        , ethereum Ethereum
        , gotPercent GotPercent
        , validAddress ValidAddress
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
    | ValidAddress { input : String, valid : Bool }
    | SelectedAccount (Maybe String)
    | Pay Float String
      -- TxHash is paying
    | TxHash ()
      -- Receipt is paid
    | Receipt { txHash : String, signature : { signature : String, msg : String } }



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
            let
                percentToFloatResult =
                    String.toFloat percent
            in
                ( { model
                    | percent =
                        case percentToFloatResult of
                            Ok percent ->
                                Just percent

                            Err _ ->
                                Nothing
                        -- FIXME Nothing means that Error appears to user same as before percent is known ("getting %")
                  }
                , Cmd.none
                )

        Amount input ->
            ( { model
                | amount =
                    case input of
                        "" ->
                            Nothing

                        _ ->
                            let
                                amount =
                                    Result.withDefault 0 (String.toFloat input)
                            in
                                if amount > 0 then
                                    Just amount
                                else
                                    Nothing
              }
            , Cmd.none
            )

        Donee input ->
            case input of
                "" ->
                    ( { model | donee = Nothing }, Cmd.none )

                _ ->
                    ( model, validateAddress input )

        ValidAddress { input, valid } ->
            ( { model
                | donee =
                    if valid then
                        Just input
                    else
                        Nothing
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
            ( { model | payment = Paid txHash { signature = signature.signature, msg = signature.msg } }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ div [] [ h3 [] [ a [ href "mailto:w.white9@icloud.com" ] [ text "email" ] ] ]
        , div [] [ h3 [] [ text "pay" ] ]
        , div []
            (case model.ethereum of
                False ->
                    [ text "Install MetaMask" ]

                True ->
                    case model.percent of
                        Nothing ->
                            [ text "getting %" ]

                        Just percent ->
                            case model.payment of
                                Unpaid ->
                                    case model.selectedAccount of
                                        Just NonPayee ->
                                            case model.amount of
                                                Just amount ->
                                                    case model.donee of
                                                        Just donee ->
                                                            fields percent ++ [ button [ onClick (Pay amount donee) ] [ text "OK" ] ]

                                                        Nothing ->
                                                            fields percent

                                                Nothing ->
                                                    fields percent

                                        Just Payee ->
                                            [ div [] [ text "Payee's account selected in MetaMask. Switch account." ] ] ++ fields percent

                                        Nothing ->
                                            [ div [] [ text "Unlock MetaMask" ] ] ++ fields percent

                                Paying ->
                                    [ text "paying" ]

                                Paid txHash { signature, msg } ->
                                    [ text ("paid: receipt: transaction: " ++ txHash ++ " signature: " ++ signature ++ " msg: " ++ msg) ]
            )
        ]



-- VIEW HELPERS


fields percent =
    [ label [ style [ ( "display", "block" ) ] ]
        [ text "amount ", input [ type_ "number", Html.Attributes.min "0", onInput Amount ] [], text " ETH" ]
    , label [ style [ ( "display", "block" ) ] ]
        [ text ("donate " ++ (toString percent) ++ "% to ")
        , input [ type_ "text", placeholder "Ethereum address", onInput Donee ] []
        ]
    ]
